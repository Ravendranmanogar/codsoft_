import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> with SingleTickerProviderStateMixin {
  List<Task> _tasks = [];
  final TextEditingController _taskController = TextEditingController();
  DateTime? _selectedDueDate;
  late AnimationController _blinkController;
  bool _shouldBlink = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

  }

  @override
  void dispose() {
    _taskController.dispose();
    _blinkController.dispose();
    super.dispose();
  }


  void _loadTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedTasks = prefs.getStringList('tasks');
    if (savedTasks != null) {
      setState(() {
        _tasks = savedTasks.map((taskString) => Task.fromJson(taskString)).toList();
      });
    }
  }


  void _saveTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> taskStrings = _tasks.map((task) => task.toJson()).toList();
    await prefs.setStringList('tasks', taskStrings);
  }


  void _addTask(String taskTitle) {
    if (taskTitle.isNotEmpty && _selectedDueDate != null) {
      setState(() {
        _tasks.insert(
          0,
          Task(
            title: taskTitle,
            isCompleted: false,
            dueDate: _selectedDueDate!,
          ),
        );
        _saveTasks();
      });
      _taskController.clear();
      _selectedDueDate = null;
      _shouldBlink = false;
    } else if (_selectedDueDate == null) {
      _triggerBlinkEffect();
    }
  }

  // Trigger blink effect
  void _triggerBlinkEffect() {
    _shouldBlink = true;
    _blinkController.repeat(reverse: true);


    Future.delayed(const Duration(milliseconds: 1500), () {
      _blinkController.stop();
      _shouldBlink = false;
    });
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
      _saveTasks(); // Save tasks after deleting a task
    });
  }

  void _editTask(int index) {
    _taskController.text = _tasks[index].title;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Edit Task"),
          content: TextField(
            controller: _taskController,
            decoration: const InputDecoration(hintText: "Enter new task"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _tasks[index].title = _taskController.text;
                  _saveTasks(); // Save tasks after editing a task
                });
                _taskController.clear();
                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _toggleTaskCompletion(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
      _saveTasks(); // Save tasks after changing completion status
    });
    _sortTasks();
  }
  void _sortTasks() {
    setState(() {
      _tasks.sort((a, b) {
        if (a.isCompleted && !b.isCompleted) {
          return 1; // Completed tasks go below
        } else if (!a.isCompleted && b.isCompleted) {
          return -1; // Incomplete tasks stay on top
        } else {
          return 0; // No change for same status tasks
        }
      });
    });
  }

  void _pickDueDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text("To-Do List",style: TextStyle(fontSize: 25,color: Colors.white,fontWeight: FontWeight.bold),),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 100.0),
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                final now = DateTime.now();
                bool isOverdue = !task.isCompleted && task.dueDate.isBefore(now);

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    title: Text(
                      task.title,
                      style: TextStyle(
                        color: isOverdue ? Colors.red : null,
                        decoration: task.isCompleted || isOverdue
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    subtitle: Text(
                      'Due: ${DateFormat.yMMMd().format(task.dueDate)}',
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.black,
                      ),
                    ),
                    leading: Checkbox(
                      value: task.isCompleted,
                      onChanged: (bool? value) {
                        _toggleTaskCompletion(index);
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editTask(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteTask(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskController,
                          decoration: const InputDecoration(
                            hintText: "Enter New Tasks Here",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _blinkController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _shouldBlink
                                ? (0.5 + 0.5 * _blinkController.value)
                                : 1.0, // Blink effect
                            child: IconButton(
                              color: Colors.red,
                              onPressed: () => _pickDueDate(context),
                              icon: const Icon(Icons.calendar_month_outlined,size: 30.0),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _addTask(_taskController.text),
                    child: const Text("Add Task"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Task model
class Task {
  String title;
  bool isCompleted;
  DateTime dueDate;

  Task({required this.title, this.isCompleted = false, required this.dueDate});

  // Convert Task object to JSON string
  String toJson() {
    return '{"title": "$title", "isCompleted": $isCompleted, "dueDate": "${dueDate.toIso8601String()}"}';
  }

  // Create a Task object from JSON string
  factory Task.fromJson(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return Task(
      title: json['title'],
      isCompleted: json['isCompleted'],
      dueDate: DateTime.parse(json['dueDate']),
    );
  }
}
