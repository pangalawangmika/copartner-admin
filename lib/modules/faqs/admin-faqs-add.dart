import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool> showAddFaqModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AddFaqModal(),
  ).then((value) => value ?? false);
}

class _AddFaqModal extends StatefulWidget {
  @override
  State<_AddFaqModal> createState() => _AddFaqModalState();
}

class _AddFaqModalState extends State<_AddFaqModal> {
  final TextEditingController mainCategoryController = TextEditingController();
  List<_SubCategoryEntry> subCategories = [_SubCategoryEntry()];
  bool isSaving = false;

  void _addSubCategory() {
    setState(() {
      subCategories.add(_SubCategoryEntry());
    });
  }

  void _removeSubCategory(int index) {
    setState(() {
      subCategories.removeAt(index);
    });
  }

  void _addPattern(int subCatIndex) {
    setState(() {
      subCategories[subCatIndex]
          .patternsControllers
          .add(TextEditingController());
    });
  }

  void _removePattern(int subCatIndex, int patternIndex) {
    setState(() {
      subCategories[subCatIndex].patternsControllers.removeAt(patternIndex);
    });
  }

  void _onSave() async {
    setState(() {
      isSaving = true;
    });
    final supabase = Supabase.instance.client;
    try {
      // 1. Insert or get category
      final mainCategory = mainCategoryController.text.trim();
      if (mainCategory.isEmpty) throw Exception('Main Category is required');
      // Check if category exists
      final existingCats =
          await supabase.from('categories').select().eq('name', mainCategory);
      int categoryId;
      if (existingCats.isNotEmpty) {
        categoryId = existingCats.first['id'] as int;
      } else {
        final insertedCat = await supabase
            .from('categories')
            .insert({'name': mainCategory}).select();
        if (insertedCat.isEmpty) throw Exception('Failed to insert category');
        categoryId = insertedCat.first['id'] as int;
      }
      // 2. Insert issues, solutions, and patterns
      for (final subCat in subCategories) {
        final subCatTitle = subCat.subCategoryController.text.trim();
        if (subCatTitle.isEmpty) continue;
        // Insert issue
        final insertedIssue = await supabase.from('issues').insert({
          'title': subCatTitle,
          'category_id': categoryId,
        }).select();
        if (insertedIssue.isEmpty) throw Exception('Failed to insert issue');
        final issueId = insertedIssue.first['id'] as int;
        // Insert solution
        final enSolution = subCat.solutionEnglishController.text.trim();
        final tlSolution = subCat.solutionTagalogController.text.trim();
        if (enSolution.isNotEmpty || tlSolution.isNotEmpty) {
          await supabase.from('solutions').insert({
            'issue_id': issueId,
            'en_solution': enSolution,
            'tl_solution': tlSolution,
          });
        }
        // Insert patterns
        for (final patternCtrl in subCat.patternsControllers) {
          final patternText = patternCtrl.text.trim();
          if (patternText.isNotEmpty) {
            await supabase.from('patterns').insert({
              'issue_id': issueId,
              'pattern': patternText,
            });
          }
        }
      }
      setState(() {
        isSaving = false;
      });
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue/Concern added successfully!')),
      );
    } catch (e) {
      setState(() {
        isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(0),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxWidth: 900),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF23225C),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Issue/Concern',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Add scrollable content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: SizedBox(
                height: 500, // Constrain height for scroll
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Main Category',
                              style: TextStyle(fontSize: 18)),
                          Text(' *',
                              style:
                                  TextStyle(color: Colors.red, fontSize: 18)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: mainCategoryController,
                        decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: 'Type here...'),
                      ),
                      const SizedBox(height: 18),
                      ...List.generate(
                          subCategories.length, (i) => _buildSubCategory(i)),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: _addSubCategory,
                            child: const Text('+ Add New Sub-Category',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 15)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: isSaving ? null : _onSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF131440),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white)))
                                : const Text('Save',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategory(int index) {
    final entry = subCategories[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Sub-Category', style: TextStyle(fontSize: 16)),
              Text(' *', style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.subCategoryController,
                  decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'Type here...'),
                ),
              ),
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Remove',
                  onPressed: () => _removeSubCategory(index),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Solution', style: TextStyle(fontSize: 15)),
                    Text(' (English)',
                        style:
                            TextStyle(fontSize: 15, color: Color(0xFFB0B0B0))),
                    Text(' *',
                        style: TextStyle(color: Colors.red, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: entry.solutionEnglishController,
                  decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'Type here...'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Solution', style: TextStyle(fontSize: 15)),
                    Text(' (Tagalog)',
                        style:
                            TextStyle(fontSize: 15, color: Color(0xFFB0B0B0))),
                    Text(' *',
                        style: TextStyle(color: Colors.red, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: entry.solutionTagalogController,
                  decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'Type here...'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Patterns', style: TextStyle(fontSize: 15)),
                    Text(' *',
                        style: TextStyle(color: Colors.red, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                ...List.generate(
                    entry.patternsControllers.length,
                    (pIdx) => Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: entry.patternsControllers[pIdx],
                                  decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      hintText: 'Type here...'),
                                ),
                              ),
                              if (entry.patternsControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  tooltip: 'Remove Pattern',
                                  onPressed: () => _removePattern(index, pIdx),
                                ),
                            ],
                          ),
                        )),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _addPattern(index),
                      child: const Text('+ Add Pattern',
                          style: TextStyle(color: Colors.grey, fontSize: 15)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubCategoryEntry {
  final TextEditingController subCategoryController = TextEditingController();
  final TextEditingController solutionEnglishController =
      TextEditingController();
  final TextEditingController solutionTagalogController =
      TextEditingController();
  List<TextEditingController> patternsControllers = [TextEditingController()];
}
