import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:shared_preferences/shared_preferences.dart'; // For saving data
import 'dart:convert'; // For JSON conversion
//import 'package:flutter/scheduler.dart'; // For animation

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
  TextEditingController _taskController = TextEditingController();
  DateTime? _selectedDueDate;
  late AnimationController _blinkController;
  bool _shouldBlink = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();

    // Initialize the animation controller for the blinking effect
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Total duration for blink cycle
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  // Load tasks from SharedPreferences
  void _loadTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedTasks = prefs.getStringList('tasks');
    if (savedTasks != null) {
      setState(() {
        _tasks = savedTasks.map((taskString) => Task.fromJson(taskString)).toList();
      });
    }
  }

  // Save tasks to SharedPreferences
  void _saveTasks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> taskStrings = _tasks.map((task) => task.toJson()).toList();
    await prefs.setStringList('tasks', taskStrings);
  }

  // Method to add task with a due date
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
        _saveTasks(); // Save tasks after adding a new task
      });
      _taskController.clear();
      _selectedDueDate = null;
      _shouldBlink = false; // Reset the blink effect if date is selected
    } else if (_selectedDueDate == null) {
      _triggerBlinkEffect(); // Trigger the blink if no due date is selected
    }
  }

  // Trigger blink effect
  void _triggerBlinkEffect() {
    _shouldBlink = true;
    _blinkController.repeat(reverse: true);

    // Stop the blinking after 3 blinks (3 * 500ms = 1.5s)
    Future.delayed(const Duration(milliseconds: 1500), () {
      _blinkController.stop();
      _shouldBlink = false;
    });
  }

  // Method to delete task
  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
      _saveTasks(); // Save tasks after deleting a task
    });
  }

  // Method to edit task
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

  // Method to toggle task completion status
  void _toggleTaskCompletion(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
      _saveTasks(); // Save tasks after changing completion status
    });
    _sortTasks();
  }

  // Sort tasks: incomplete tasks on top, completed tasks below
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

  // Method to pick a due date
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
        title: const Text("To-Do List"),
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
                    color: Colors.grey.shade200, // Grey background for task container
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
          // Text field and due date picker at the bottom
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
