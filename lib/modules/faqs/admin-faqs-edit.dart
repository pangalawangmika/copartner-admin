import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool> showEditFaqModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _EditFaqModal(),
  ).then((value) => value ?? false);
}

class _EditFaqModal extends StatefulWidget {
  @override
  State<_EditFaqModal> createState() => _EditFaqModalState();
}

class _EditFaqModalState extends State<_EditFaqModal> {
  final supabase = Supabase.instance.client;
  int? selectedCategoryId;
  int? selectedIssueId;
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subCategories = [];
  TextEditingController solutionEnglishController = TextEditingController();
  TextEditingController solutionTagalogController = TextEditingController();
  List<TextEditingController> patternsControllers = [];
  bool isSaving = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      isLoading = true;
    });
    try {
      final cats = await supabase.from('categories').select().order('id');
      setState(() {
        categories = List<Map<String, dynamic>>.from(cats)
          ..sort((a, b) => a['id'].compareTo(b['id']));
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Handle error if needed
    }
  }

  Future<void> _onCategorySelected(int? catId) async {
    setState(() {
      selectedCategoryId = catId;
      selectedIssueId = null;
      subCategories = [];
      solutionEnglishController.clear();
      solutionTagalogController.clear();
      patternsControllers.clear();
    });
    if (catId == null) return;
    final issues = await supabase
        .from('issues')
        .select()
        .eq('category_id', catId)
        .order('id');
    setState(() {
      subCategories = List<Map<String, dynamic>>.from(issues)
        ..sort((a, b) => a['id'].compareTo(b['id']));
    });
  }

  Future<void> _onIssueSelected(int? issueId) async {
    setState(() {
      selectedIssueId = issueId;
      solutionEnglishController.clear();
      solutionTagalogController.clear();
      patternsControllers.clear();
    });
    if (issueId == null) return;
    // Fetch solution
    final solutions =
        await supabase.from('solutions').select().eq('issue_id', issueId);
    if (solutions.isNotEmpty) {
      solutionEnglishController.text = solutions.first['en_solution'] ?? '';
      solutionTagalogController.text = solutions.first['tl_solution'] ?? '';
    }
    // Fetch patterns
    final patterns =
        await supabase.from('patterns').select().eq('issue_id', issueId);
    setState(() {
      patternsControllers = List.generate(
        patterns.length,
        (i) => TextEditingController(text: patterns[i]['pattern'] ?? ''),
      );
      if (patternsControllers.isEmpty) {
        patternsControllers.add(TextEditingController());
      }
    });
  }

  void _addPattern() {
    setState(() {
      patternsControllers.add(TextEditingController());
    });
  }

  void _removePattern(int index) {
    setState(() {
      patternsControllers.removeAt(index);
    });
  }

  void _onSave() async {
    if (selectedIssueId == null) return;
    setState(() {
      isSaving = true;
    });
    final supabase = Supabase.instance.client;
    try {
      // Update solution
      final enSolution = solutionEnglishController.text.trim();
      final tlSolution = solutionTagalogController.text.trim();

      if (enSolution.isNotEmpty || tlSolution.isNotEmpty) {
        // Check if solution exists
        final existingSolutions = await supabase
            .from('solutions')
            .select()
            .eq('issue_id', selectedIssueId!);

        if (existingSolutions.isNotEmpty) {
          await supabase.from('solutions').update({
            'en_solution': enSolution,
            'tl_solution': tlSolution,
          }).eq('issue_id', selectedIssueId!);
        } else {
          await supabase.from('solutions').insert({
            'issue_id': selectedIssueId!,
            'en_solution': enSolution,
            'tl_solution': tlSolution,
          });
        }
      } else {
        // If solution controllers are empty, delete existing solution if any
        await supabase
            .from('solutions')
            .delete()
            .eq('issue_id', selectedIssueId!);
      }

      // Update patterns
      await supabase.from('patterns').delete().eq('issue_id', selectedIssueId!);
      for (final ctrl in patternsControllers) {
        final patternText = ctrl.text.trim();
        if (patternText.isNotEmpty) {
          await supabase.from('patterns').insert({
            'issue_id': selectedIssueId!,
            'pattern': patternText,
          });
        }
      }

      setState(() {
        isSaving = false;
      });
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue/Concern updated successfully!')),
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
                    'Edit Issue/Concern',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: SizedBox(
                height: 500,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Main Category',
                                style: TextStyle(fontSize: 18)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
                              value: selectedCategoryId,
                              items: categories.map((cat) {
                                return DropdownMenuItem<int>(
                                  value: cat['id'],
                                  child: Text(cat['name']),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  _onCategorySelected(val as int?),
                              hint: const Text('Select Main Category'),
                              dropdownColor: Colors.white,
                            ),
                            Row(
                              children: [
                                const Spacer(),
                                SizedBox(
                                  height: 56,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(80, 56),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                    ),
                                    onPressed: selectedCategoryId == null
                                        ? null
                                        : () async {
                                            final currentName =
                                                categories.firstWhere((cat) =>
                                                    cat['id'] ==
                                                    selectedCategoryId)['name'];
                                            final controller =
                                                TextEditingController(
                                                    text: currentName);
                                            final result =
                                                await showDialog<String>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Edit Main Category'),
                                                content: TextField(
                                                  controller: controller,
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText:
                                                              'Category Name'),
                                                ),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child:
                                                          const Text('Cancel')),
                                                  ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context,
                                                              controller.text
                                                                  .trim()),
                                                      child:
                                                          const Text('Save')),
                                                ],
                                              ),
                                            );
                                            if (result != null &&
                                                result.isNotEmpty) {
                                              await supabase
                                                  .from('categories')
                                                  .update({'name': result}).eq(
                                                      'id',
                                                      selectedCategoryId!);
                                              // Reload categories after editing name
                                              await _loadCategories();
                                              // Trigger main page reload
                                              Navigator.of(context).pop(true);
                                            }
                                          },
                                    child: const Text('+ Edit'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 56,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(80, 56),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      foregroundColor: Colors.red,
                                    ),
                                    onPressed: selectedCategoryId == null
                                        ? null
                                        : () async {
                                            final confirm =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Delete Main Category'),
                                                content: const Text(
                                                    'Are you sure you want to delete this main category? This will also delete all its sub-categories, solutions, and patterns.'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      child:
                                                          const Text('Cancel')),
                                                  ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      child:
                                                          const Text('Delete')),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await supabase
                                                  .from('categories')
                                                  .delete()
                                                  .eq('id',
                                                      selectedCategoryId!);
                                              // Show success toast
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'You have successfully deleted a category')),
                                              );
                                              // Trigger main page reload after deletion
                                              Navigator.of(context).pop(true);
                                            }
                                          },
                                    child: const Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (selectedCategoryId != null) ...[
                              const Text('Sub-Category',
                                  style: TextStyle(fontSize: 16)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder()),
                                value: selectedIssueId,
                                items: subCategories.map((issue) {
                                  return DropdownMenuItem<int>(
                                    value: issue['id'],
                                    child: Text(issue['title']),
                                  );
                                }).toList(),
                                onChanged: (val) =>
                                    _onIssueSelected(val as int?),
                                hint: const Text('Select Sub-Category'),
                                dropdownColor: Colors.white,
                              ),
                              Row(
                                children: [
                                  const Spacer(),
                                  SizedBox(
                                    height: 56,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(80, 56),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                      ),
                                      onPressed: selectedIssueId == null
                                          ? null
                                          : () async {
                                              final currentName = subCategories
                                                  .firstWhere((issue) =>
                                                      issue['id'] ==
                                                      selectedIssueId)['title'];
                                              final controller =
                                                  TextEditingController(
                                                      text: currentName);
                                              final result =
                                                  await showDialog<String>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: const Text(
                                                      'Edit Sub-Category'),
                                                  content: TextField(
                                                    controller: controller,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Sub-Category Name'),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: const Text(
                                                            'Cancel')),
                                                    ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context,
                                                                controller.text
                                                                    .trim()),
                                                        child:
                                                            const Text('Save')),
                                                  ],
                                                ),
                                              );
                                              if (result != null &&
                                                  result.isNotEmpty) {
                                                await supabase
                                                    .from('issues')
                                                    .update({
                                                  'title': result
                                                }).eq('id', selectedIssueId!);
                                                // Reload issues for the current category after editing
                                                await _onCategorySelected(
                                                    selectedCategoryId);
                                                // Trigger main page reload
                                                Navigator.of(context).pop(true);
                                              }
                                            },
                                      child: const Text('+ Edit'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 56,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(80, 56),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        foregroundColor: Colors.red,
                                      ),
                                      onPressed: selectedIssueId == null
                                          ? null
                                          : () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: const Text(
                                                      'Delete Sub-Category'),
                                                  content: const Text(
                                                      'Are you sure you want to delete this sub-category? This will also delete its solutions and patterns.'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: const Text(
                                                            'Cancel')),
                                                    ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: const Text(
                                                            'Delete')),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await supabase
                                                    .from('issues')
                                                    .delete()
                                                    .eq('id', selectedIssueId!);
                                                // Show success toast
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'You have successfully deleted a sub category')),
                                                );
                                                // Trigger main page reload after deletion
                                                Navigator.of(context).pop(true);
                                              }
                                            },
                                      child: const Text('Delete'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (selectedIssueId != null) ...[
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.only(left: 24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Solution',
                                        style: TextStyle(fontSize: 15)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: solutionEnglishController,
                                      minLines: 3,
                                      maxLines: null,
                                      decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          hintText: 'Type here...'),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text('Solution',
                                        style: TextStyle(fontSize: 15)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: solutionTagalogController,
                                      minLines: 3,
                                      maxLines: null,
                                      decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          hintText: 'Type here...'),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text('Patterns',
                                        style: TextStyle(fontSize: 15)),
                                    const SizedBox(height: 6),
                                    ...List.generate(
                                        patternsControllers.length,
                                        (pIdx) => Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10.0),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          patternsControllers[
                                                              pIdx],
                                                      decoration:
                                                          const InputDecoration(
                                                              isDense: true,
                                                              border:
                                                                  OutlineInputBorder()),
                                                    ),
                                                  ),
                                                  if (patternsControllers
                                                          .length >
                                                      1)
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete,
                                                          color: Colors.red),
                                                      tooltip: 'Remove Pattern',
                                                      onPressed: () =>
                                                          _removePattern(pIdx),
                                                    ),
                                                ],
                                              ),
                                            )),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: _addPattern,
                                          child: const Text('+ Add Pattern',
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 15)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                                              fontSize: 16,
                                              color: Colors.white)),
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
}

class _SubCategoryEntry {
  final TextEditingController subCategoryController = TextEditingController();
  final TextEditingController solutionEnglishController =
      TextEditingController();
  final TextEditingController solutionTagalogController =
      TextEditingController();
  List<TextEditingController> patternsControllers = [TextEditingController()];
}
