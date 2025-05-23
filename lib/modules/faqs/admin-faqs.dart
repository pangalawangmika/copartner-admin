import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin-faqs-add.dart';
import 'admin-faqs-edit.dart';

class FaqsManagementPage extends StatefulWidget {
  const FaqsManagementPage({super.key});

  @override
  State<FaqsManagementPage> createState() => _FaqsManagementPageState();
}

class _FaqsManagementPageState extends State<FaqsManagementPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> categories = [];
  Map<int, List<Map<String, dynamic>>> issuesByCategory = {};
  Map<int, Map<String, dynamic>> solutionsAndPatternsByIssue = {};
  int? expandedCategoryId;
  int? expandedIssueId;
  int? expandedPatternIssueId;
  int? selectedCategoryId;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final cats = await supabase.from('categories').select().order('id');
      final issues = await supabase.from('issues').select().order('id');
      final solutions = await supabase.from('solutions').select().order('id');
      final patterns = await supabase.from('patterns').select().order('id');

      final Map<int, List<Map<String, dynamic>>> issuesGrouped = {};
      for (final issue in issues) {
        final catId = issue['category_id'] as int;
        issuesGrouped.putIfAbsent(catId, () => []).add(issue);
      }

      final Map<int, Map<String, dynamic>> combined = {};
      for (final issue in issues) {
        final issueId = issue['id'] as int;
        final issueSolutions =
            solutions.where((s) => s['issue_id'] == issueId).toList();
        final issuePatterns =
            patterns.where((p) => p['issue_id'] == issueId).toList();

        combined[issueId] = {
          'solutions': issueSolutions,
          'patterns': issuePatterns,
        };
      }

      setState(() {
        categories = List<Map<String, dynamic>>.from(cats)
          ..sort((a, b) => a['id'].compareTo(b['id']));
        issuesByCategory = issuesGrouped;
        solutionsAndPatternsByIssue = combined;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  void _showEditIssueModal() {
    showEditFaqModal(context).then((result) {
      if (result == true) {
        _loadAllData(); // Reload data if save was successful
      }
    });
  }

  void _showAddIssueModal() {
    showAddFaqModal(context).then((result) {
      if (result == true) {
        _loadAllData(); // Reload data if save was successful
      }
    });
  }

  Widget _buildSolutionBlock(Map<String, dynamic> solution) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("English", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(solution['en_solution'] ?? ''),
          const SizedBox(height: 8),
          const Text("Tagalog", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(solution['tl_solution'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildPatternExpansion(
      int issueId, List<Map<String, dynamic>> patterns) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.only(left: 8),
        title: const Align(
          alignment: Alignment.centerLeft,
          child:
              Text('Patterns', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        initiallyExpanded: expandedPatternIssueId == issueId,
        onExpansionChanged: (val) {
          setState(() {
            expandedPatternIssueId = val ? issueId : null;
          });
        },
        children: patterns
            .map((p) => Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 4),
                    child: Text('- ${p['pattern']}'),
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text(
                  'Issues & Concern Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  width: 990,
                  height: 550,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Select Category to View',
                                border: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      color: Color(0xFF131440)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      color: Color(0xFF131440)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: const BorderSide(
                                      color: Color(0xFF131440), width: 2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                labelStyle:
                                    const TextStyle(color: Color(0xFF131440)),
                              ),
                              value: selectedCategoryId,
                              items: categories.map((cat) {
                                return DropdownMenuItem<int>(
                                  value: cat['id'],
                                  child: Text(cat['name'],
                                      style: const TextStyle(
                                          color: Color(0xFF131440))),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedCategoryId = value;
                                  expandedCategoryId = null;
                                  expandedIssueId = null;
                                  expandedPatternIssueId = null;
                                });
                              },
                              dropdownColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _showEditIssueModal,
                              icon: const Icon(Icons.edit,
                                  size: 18, color: Colors.white),
                              label: const Text("Edit Issue/Concern",
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF131440),
                                minimumSize: const Size(80, 56),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _showAddIssueModal,
                              icon: const Icon(Icons.add,
                                  size: 18, color: Colors.white),
                              label: const Text("Add New Issue/Concern",
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF131440),
                                minimumSize: const Size(80, 56),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (selectedCategoryId != null)
                        Expanded(
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Builder(
                                    builder: (_) {
                                      final category = categories.firstWhere(
                                          (cat) =>
                                              cat['id'] == selectedCategoryId);
                                      final catId = category['id'] as int;
                                      final isExpanded =
                                          expandedCategoryId == catId;
                                      final issues =
                                          issuesByCategory[catId] ?? [];

                                      return ExpansionTile(
                                        tilePadding: EdgeInsets.zero,
                                        title: Text(category['name'],
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        initiallyExpanded: isExpanded,
                                        onExpansionChanged: (val) {
                                          setState(() {
                                            expandedCategoryId =
                                                val ? catId : null;
                                            expandedIssueId = null;
                                            expandedPatternIssueId = null;
                                          });
                                        },
                                        children: issues.map((issue) {
                                          final issueId = issue['id'] as int;
                                          final isIssueExpanded =
                                              expandedIssueId == issueId;
                                          final solutions =
                                              solutionsAndPatternsByIssue[
                                                      issueId]?['solutions'] ??
                                                  [];
                                          final patterns =
                                              solutionsAndPatternsByIssue[
                                                      issueId]?['patterns'] ??
                                                  [];

                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(left: 16),
                                            child: ExpansionTile(
                                              key: Key('issue_$issueId'),
                                              title: Text(issue['title'],
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.normal)),
                                              initiallyExpanded:
                                                  isIssueExpanded,
                                              onExpansionChanged: (val) {
                                                setState(() {
                                                  expandedIssueId =
                                                      val ? issueId : null;
                                                });
                                              },
                                              children: [
                                                if (solutions.isEmpty)
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                    child: Text(
                                                        'No solutions available.'),
                                                  ),
                                                ...solutions.map((s) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 8.0,
                                                              bottom: 8),
                                                      child:
                                                          _buildSolutionBlock(
                                                              s),
                                                    )),
                                                if (patterns.isNotEmpty)
                                                  _buildPatternExpansion(
                                                      issueId,
                                                      List<
                                                              Map<String,
                                                                  dynamic>>.from(
                                                          patterns)),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
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
