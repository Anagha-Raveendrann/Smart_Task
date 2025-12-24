import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smart_task/model/task.dart';

class TaskViewModel extends ChangeNotifier {
  List<Task> _tasks = [];
  List<Task> get tasks => _tasks;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  List<Task> get filteredTasks {
    if (_searchQuery.isEmpty) return _tasks;
    return _tasks
        .where(
          (task) =>
              task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (task.description?.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false),
        )
        .toList();
  }

  TaskViewModel() {
    _init();
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      final wasOnline = _isOnline;
      _isOnline =
          result.isNotEmpty && result.any((r) => r != ConnectivityResult.none);
      if (!wasOnline && _isOnline) {
        retrySync();
      }
      notifyListeners();
    });
  }

  Future<void> _init() async {
    await _loadFromLocal();
    await _checkConnectivity();
    await loadTasks();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline =
        results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
    notifyListeners();
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getStringList('tasks') ?? [];
    _tasks = tasksJson.map((json) => Task.fromJson(jsonDecode(json))).toList();
    notifyListeners();
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = _tasks.map((task) => jsonEncode(task.toJson())).toList();
    await prefs.setStringList('tasks', tasksJson);
  }

  Future<void> loadTasks({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));

      final newTasks = List.generate(
        10,
        (index) => Task(
          title: 'Task ${(_currentPage - 1) * _pageSize + index + 1}',
          description:
              'Description for task ${(_currentPage - 1) * _pageSize + index + 1}',
          completed: index % 3 == 0,
        ),
      );

      if (refresh) {
        _tasks = newTasks;
      } else {
        _tasks.addAll(newTasks);
      }

      _currentPage++;
      if (newTasks.length < _pageSize) {
        _hasMore = false;
      }

      await _saveToLocal();
    } catch (e) {
      _error = 'Failed to load tasks';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTask(Task task) async {
    _tasks.insert(0, task);
    notifyListeners();
    await _saveToLocal();

    if (_isOnline) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));

        task = task.copyWith(isSynced: true);
        _updateTaskInList(task);
      } catch (e) {
        task = task.copyWith(isSynced: false);
        _updateTaskInList(task);
        _error = 'Failed to sync task';
      }
    } else {
      task = task.copyWith(isSynced: false);
      _updateTaskInList(task);
    }
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    _updateTaskInList(task);
    notifyListeners();
    await _saveToLocal();

    if (_isOnline) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        task = task.copyWith(isSynced: true);
        _updateTaskInList(task);
      } catch (e) {
        task = task.copyWith(isSynced: false);
        _updateTaskInList(task);
        _error = 'Failed to sync task';
      }
    } else {
      task = task.copyWith(isSynced: false);
      _updateTaskInList(task);
    }
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id);
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveToLocal();

    if (_isOnline) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        _tasks.insert(0, task.copyWith(isSynced: false));
        _error = 'Failed to sync delete';
        notifyListeners();
      }
    } else {
      _tasks.insert(0, task.copyWith(isSynced: false));
      notifyListeners();
    }
  }

  void _updateTaskInList(Task task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> retrySync() async {
    await _checkConnectivity();
    if (!_isOnline) return;

    final unsyncedTasks = _tasks.where((t) => !t.isSynced).toList();
    for (final task in unsyncedTasks) {
      await Future.delayed(const Duration(milliseconds: 200));
      _updateTaskInList(task.copyWith(isSynced: true));
    }
    await _saveToLocal();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
