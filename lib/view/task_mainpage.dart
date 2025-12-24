import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_task/model/task.dart';
import 'package:smart_task/view/add_task.dart';
import 'package:smart_task/viewmodel/task_viewmodel.dart';

class TaskMainpage extends StatefulWidget {
  const TaskMainpage({super.key});

  @override
  State<TaskMainpage> createState() => _TaskMainpageState();
}

class _TaskMainpageState extends State<TaskMainpage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quickTaskController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quickTaskController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final viewModel = Provider.of<TaskViewModel>(context, listen: false);
      viewModel.loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline),
            SizedBox(width: 8),
            Text("All List"),
            Icon(Icons.arrow_drop_down),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Consumer<TaskViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(viewModel.error!)));
              viewModel.clearError();
            });
          }

          if (viewModel.isLoading && viewModel.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.tasks.isEmpty && !viewModel.isLoading) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => viewModel.loadTasks(refresh: true),
            child: ListView.builder(
              controller: _scrollController,
              itemCount:
                  viewModel.filteredTasks.length + (viewModel.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == viewModel.filteredTasks.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final task = viewModel.filteredTasks[index];
                return _buildTaskItem(task, viewModel);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1976D2),
        onPressed: () => _navigateToAddTask(),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.task_alt, size: 100, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No tasks yet",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Task task, TaskViewModel viewModel) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) => viewModel.deleteTask(task.id),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (value) =>
              viewModel.updateTask(task.copyWith(completed: value ?? false)),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null) Text(task.description!),
            if (task.dueDate != null)
              Text(
                'Due: ${_formatDate(task.dueDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _isOverdue(task.dueDate!) ? Colors.red : Colors.grey,
                  fontWeight: _isOverdue(task.dueDate!)
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!task.isSynced)
              const Icon(Icons.sync_problem, color: Colors.orange),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToEditTask(task);
                } else if (value == 'delete') {
                  viewModel.deleteTask(task.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      color: const Color(0xFF1976D2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _quickTaskController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Enter Quick Task Here",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: () => _addQuickTask(),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Tasks'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter search query'),
          onChanged: (value) {
            if (_debounce?.isActive ?? false) _debounce!.cancel();
            _debounce = Timer(const Duration(milliseconds: 500), () {
              Provider.of<TaskViewModel>(
                context,
                listen: false,
              ).setSearchQuery(value);
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTask()),
    );
  }

  void _navigateToEditTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTask(task: task)),
    );
  }

  void _addQuickTask() {
    final title = _quickTaskController.text.trim();
    if (title.isNotEmpty) {
      final viewModel = Provider.of<TaskViewModel>(context, listen: false);
      viewModel.addTask(Task(title: title));
      _quickTaskController.clear();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);

    if (taskDate == today) {
      return 'Today';
    } else if (taskDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (taskDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  bool _isOverdue(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return taskDate.isBefore(today) && !taskDate.isAtSameMomentAs(today);
  }
}
