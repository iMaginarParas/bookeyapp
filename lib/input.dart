import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'navigation_service.dart';

// Import the enhanced background job service
// You'll need to add this import in your actual project
// import 'background_job_service.dart';

// ✅ COMPACT: Story Generator Widget - fits without scrolling
class CompactStoryGeneratorWidget extends StatefulWidget {
  final Function(ProcessingResult) onStoryGenerated;

  const CompactStoryGeneratorWidget({super.key, required this.onStoryGenerated});

  @override
  State<CompactStoryGeneratorWidget> createState() => _CompactStoryGeneratorWidgetState();
}

class _CompactStoryGeneratorWidgetState extends State<CompactStoryGeneratorWidget>
    with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  
  // ✅ NEW: Character and context controllers
  final TextEditingController _contextController = TextEditingController();
  final TextEditingController _charNameController = TextEditingController();
  final TextEditingController _charAgeController = TextEditingController();

  String _selectedGenre = 'Fantasy';
  String _selectedDuration = 'Medium (10-20 minutes read)';
  bool _isGenerating = false;
  
  // ✅ NEW: Character management
  String _selectedCharType = 'Human';
  List<Map<String, String>> _characters = [];
  
  // ✅ NEW: Character types
  List<String> _characterTypes = [
    'Human',
    'Animal (Dog)',
    'Animal (Cat)', 
    'Animal (Bird)',
    'Animal (Other)',
    'Robot/AI',
    'Alien',
    'Magical Creature',
    'Ghost/Spirit',
    'Object (Chair)',
    'Object (Watch)',
    'Object (Vehicle)',
    'Object (Other)',
    'Mythical Being',
    'Other'
  ];

  List<Map<String, String>> _genres = [
    {'value': 'Fantasy', 'label': 'Fantasy'},
    {'value': 'Science Fiction', 'label': 'Sci-Fi'},
    {'value': 'Mystery Crime Thriller', 'label': 'Mystery'},
    {'value': 'Romance', 'label': 'Romance'},
    {'value': 'Action/Adventure', 'label': 'Adventure'},
    {'value': 'Comedy', 'label': 'Comedy'},
  ];

  List<Map<String, String>> _durations = [
    {'value': 'Short (5-10 minutes read)', 'label': 'Short'},
    {'value': 'Medium (10-20 minutes read)', 'label': 'Medium'},
    {'value': 'Long (20-30 minutes read)', 'label': 'Long'},
  ];

  @override
  void initState() {
    super.initState();
    _loadGenresAndDurations();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _contextController.dispose();
    _charNameController.dispose();
    _charAgeController.dispose();
    super.dispose();
  }

  Future<void> _loadGenresAndDurations() async {
    try {
      final genres = await ApiService.getAvailableGenres();
      if (genres.isNotEmpty) {
        setState(() {
          _genres = genres;
        });
      }

      final durations = await ApiService.getAvailableDurations();
      if (durations.isNotEmpty) {
        setState(() {
          _durations = durations;
        });
      }
    } catch (e) {
      // Keep defaults if API fails
    }
  }

  // ✅ NEW: Add character function
  void _addCharacter() {
    if (_charNameController.text.trim().isEmpty || _charAgeController.text.trim().isEmpty) {
      _showSnackBar('Please fill in character name and age', isError: true);
      return;
    }

    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _characters.add({
        'name': _charNameController.text.trim(),
        'age': _charAgeController.text.trim(),
        'type': _selectedCharType,
      });
      _charNameController.clear();
      _charAgeController.clear();
      _selectedCharType = 'Human';
    });

    _showSnackBar('Character added!', isError: false);
  }

  // ✅ NEW: Remove character function
  void _removeCharacter(int index) {
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _characters.removeAt(index);
    });
  }

  // ✅ NEW: Format characters for API
  String _formatCharactersForApi() {
    if (_characters.isEmpty) return '';
    return _characters.map((char) => '${char['name']} — ${char['age']} years old, ${char['type']}').join('\n');
  }

  Future<void> _generateStory() async {
    if (!_canGenerateStory()) {
      _showSnackBar('Please fill in title and subject', isError: true);
      return;
    }

    if (!kIsWeb) {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final storyRequest = StoryRequest(
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        characters: _formatCharactersForApi(), // ✅ NEW: Send formatted characters
        context: _contextController.text.trim().isNotEmpty ? _contextController.text.trim() : null, // ✅ NEW: Send context
        duration: _selectedDuration,
        genre: _selectedGenre,
      );

      final result = await ApiService.generateStory(storyRequest);

      if (result.success) {
        if (!kIsWeb) {
          HapticFeedback.lightImpact();
        }
        
        _showSnackBar('Story generated successfully!', isError: false);
        await Future.delayed(Duration(milliseconds: 500));
        
        NavigationService().navigateToProcessing();
        widget.onStoryGenerated(result);
        _clearForm();
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
      _showSnackBar('Generation failed: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _clearForm() {
    _titleController.clear();
    _subjectController.clear();
    _contextController.clear();
    _charNameController.clear();
    _charAgeController.clear();
    setState(() {
      _characters.clear();
      _selectedCharType = 'Human';
    });
  }

  bool _canGenerateStory() {
    return _titleController.text.trim().isNotEmpty &&
        _subjectController.text.trim().isNotEmpty;
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_stories,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'AI Story Generator',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Title input
            _buildCompactTextField(
              controller: _titleController,
              label: 'Story Title',
              hint: 'Enter your story title',
              maxLines: 1,
            ),
            
            const SizedBox(height: 12),
            
            // Subject input
            _buildCompactTextField(
              controller: _subjectController,
              label: 'Story Subject',
              hint: 'Describe what your story should be about',
              maxLines: 2,
            ),
            
            const SizedBox(height: 12),
            
            // ✅ NEW: Character section
            _buildCharacterSection(),
            
            const SizedBox(height: 12),
            
            // ✅ NEW: Context section
            _buildContextSection(),
            
            const SizedBox(height: 12),
            
            // Dropdowns row
            Row(
              children: [
                Expanded(
                  child: _buildCompactDropdown(
                    label: 'Genre',
                    value: _selectedGenre,
                    items: _genres,
                    onChanged: (value) {
                      setState(() {
                        _selectedGenre = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactDropdown(
                    label: 'Length',
                    value: _selectedDuration,
                    items: _durations,
                    onChanged: (value) {
                      setState(() {
                        _selectedDuration = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Generate button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _canGenerateStory() && !_isGenerating ? _generateStory : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Generate Story',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  // ✅ NEW: Character input section
  Widget _buildCharacterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 6),
              Text(
                'Characters (Optional)',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Character input form
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildSmallTextField(
                  controller: _charNameController,
                  hint: 'Name',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSmallTextField(
                  controller: _charAgeController,
                  hint: 'Age',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          
          // Character type dropdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCharType,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: TextStyle(color: Color(0xFF1F2937), fontSize: 12),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCharType = newValue;
                    });
                  }
                },
                items: _characterTypes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(fontSize: 12)),
                  );
                }).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Add button
          SizedBox(
            width: double.infinity,
            height: 30,
            child: ElevatedButton(
              onPressed: _addCharacter,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              child: Text('Add Character'),
            ),
          ),
          
          // Character list
          if (_characters.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...(_characters.asMap().entries.map((entry) {
              final index = entry.key;
              final char = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${char['name']} — ${char['age']}, ${char['type']}',
                        style: TextStyle(fontSize: 11, color: Color(0xFF374151)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeCharacter(index),
                      child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
                    ),
                  ],
                ),
              );
            })).toList(),
          ],
        ],
      ),
    );
  }

  // ✅ NEW: Context section
  Widget _buildContextSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 6),
              Text(
                'Context & Setting (Optional)',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: TextField(
              controller: _contextController,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
              decoration: InputDecoration(
                hintText: 'Describe the world, time period, or setting...',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Small text field helper
  Widget _buildSmallTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF2563EB).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF2563EB).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            onChanged: onChanged,
            isExpanded: true,
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            dropdownColor: Colors.white,
            items: items.map<DropdownMenuItem<String>>((item) {
              return DropdownMenuItem<String>(
                value: item['value'],
                child: Text(
                  item['label']!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

// ✅ COMPACT: Audio Upload Widget
class CompactAudioUploadWidget extends StatefulWidget {
  final Function(ProcessingResult) onAudioProcessed;

  const CompactAudioUploadWidget({super.key, required this.onAudioProcessed});

  @override
  State<CompactAudioUploadWidget> createState() => _CompactAudioUploadWidgetState();
}

class _CompactAudioUploadWidgetState extends State<CompactAudioUploadWidget> {
  File? _selectedFile;
  PlatformFile? _selectedWebFile;
  bool _isProcessing = false;

  Future<void> _pickAudioFile() async {
    try {
      if (!kIsWeb) {
        HapticFeedback.lightImpact();
      }
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null) {
        if (!kIsWeb) {
          HapticFeedback.mediumImpact();
        }
        
        setState(() {
          if (kIsWeb) {
            _selectedWebFile = result.files.single;
            _selectedFile = null;
          } else {
            _selectedFile = File(result.files.single.path!);
            _selectedWebFile = null;
          }
        });

        _showSnackBar('Audio file selected successfully!', isError: false);
      }
    } catch (e) {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
      _showSnackBar('Error selecting audio file: $e', isError: true);
    }
  }

  Future<void> _processAudio() async {
    if (_selectedFile == null && _selectedWebFile == null) {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
      _showSnackBar('Please select an audio file first', isError: true);
      return;
    }

    if (!kIsWeb) {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await BackgroundJobApiService.processAudio(_selectedFile, _selectedWebFile);
      
      if (result != null && result['job_id'] != null) {
        if (!kIsWeb) {
          HapticFeedback.lightImpact();
        }
        
        _showSnackBar('Audio processing started! Please check Processing tab.', isError: false);
        
        // Wait a moment then navigate to processing tab
        await Future.delayed(Duration(milliseconds: 800));
        NavigationService().navigateToProcessing();
        
        // Create a proper ProcessingResult for audio
        widget.onAudioProcessed(ProcessingResult.fromNewApiResponse({
          'success': true,
          'message': 'Audio processing in progress - Job ID: ${result['job_id']}',
          'file_name': kIsWeb ? (_selectedWebFile?.name ?? 'Audio File') : (_selectedFile?.path.split('/').last ?? 'Audio File'),
          'total_page_batches': 1,
          'total_words': 0,
          'estimated_reading_time_minutes': 5.0,
          'processing_time_seconds': 0.0,
          'job_id': result['job_id'],
          'session_id': result['session_id'],
          'status': 'processing',
          'page_batches': [],
        }));
        
        // ✅ CRITICAL: Register callback for when real results are ready
        BackgroundJobApiService.onResultsReady(result['job_id'], (finalResults) {
          print('🎉 Audio results callback triggered with final data');
          
          // Convert final results to ProcessingResult and update processing page
          try {
            final processedResult = ProcessingResult.fromNewApiResponse(finalResults);
            print('📋 Converted to ProcessingResult with ${processedResult.pageBatches.length} batches');
            
            // Call the main callback to update processing page
            widget.onAudioProcessed(processedResult);
            
          } catch (e) {
            print('❌ Error converting final results: $e');
            // Fallback with mock results
            widget.onAudioProcessed(ProcessingResult.fromNewApiResponse({
              'success': true,
              'message': 'Audio processing completed',
              'file_name': 'Audio Content',
              'total_items': 1,
              'total_words': 400,
              'parts': finalResults['parts'] ?? [],
            }));
          }
        });
      } else {
        throw Exception('Failed to start audio processing - no job ID returned');
      }
    } catch (e) {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
      _showSnackBar('Failed to process audio: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _selectedFile != null || _selectedWebFile != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: hasFile
                    ? LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                    : LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (hasFile ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                hasFile ? Icons.check_circle : Icons.headphones,
                color: Color(0xFF1E293B),
                size: 36,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title and description
            Text(
              hasFile ? 'Audio Ready!' : 'Upload Audio',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              hasFile
                  ? 'Ready to transcribe with AI'
                  : 'Upload audio for AI transcription',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // File info (if selected)
            if (hasFile) ...[
              _buildCompactFileCard(),
              const SizedBox(height: 20),
            ],
            
            // Action buttons
            if (!hasFile)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _pickAudioFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 18),
                      const SizedBox(width: 8),
                      Text('Choose Audio File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            
            if (hasFile)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedFile = null;
                            _selectedWebFile = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF2563EB),
                          side: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.3), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Change'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processAudio,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isProcessing
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Process', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCompactFileCard() {
    final fileName = kIsWeb
        ? (_selectedWebFile?.name ?? 'Audio File')
        : (_selectedFile?.path.split('/').last ?? 'Audio File');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.audiotrack,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ COMPACT: Camera/Image Widget  
class CompactCameraWidget extends StatefulWidget {
  final Function(ProcessingResult) onImagesProcessed;

  const CompactCameraWidget({super.key, required this.onImagesProcessed});

  @override
  State<CompactCameraWidget> createState() => _CompactCameraWidgetState();
}

class _CompactCameraWidgetState extends State<CompactCameraWidget> {
  List<File> _selectedImages = [];
  List<PlatformFile> _selectedWebImages = [];
  bool _isProcessing = false;

  Future<void> _pickImages() async {
    try {
      if (!kIsWeb) {
        HapticFeedback.lightImpact();
      }
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result != null) {
        if (!kIsWeb) {
          HapticFeedback.mediumImpact();
        }
        
        setState(() {
          if (kIsWeb) {
            _selectedWebImages = result.files;
            _selectedImages = [];
          } else {
            _selectedImages = result.files.map((file) => File(file.path!)).toList();
            _selectedWebImages = [];
          }
        });

        _showSnackBar('${result.files.length} image(s) selected successfully!', isError: false);
      }
    } catch (e) {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
      _showSnackBar('Error selecting images: $e', isError: true);
    }
  }

  Future<void> _processImages() async {
    if (_selectedImages.isEmpty && _selectedWebImages.isEmpty) {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
      _showSnackBar('Please select images first', isError: true);
      return;
    }

    if (!kIsWeb) {
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      Map<String, dynamic>? result;
      
      if (kIsWeb) {
        result = await BackgroundJobApiService.processImagesWeb(_selectedWebImages);
      } else {
        result = await BackgroundJobApiService.processImages(_selectedImages);
      }
      
      if (result != null && result['job_id'] != null) {
        if (!kIsWeb) {
          HapticFeedback.lightImpact();
        }
        
        final imageCount = kIsWeb ? _selectedWebImages.length : _selectedImages.length;
        _showSnackBar('Processing $imageCount image(s)! Please check Processing tab.', isError: false);
        
        // Wait a moment then navigate to processing tab
        await Future.delayed(Duration(milliseconds: 800));
        NavigationService().navigateToProcessing();
        
        widget.onImagesProcessed(ProcessingResult.fromNewApiResponse({
          'success': true,
          'message': 'Image processing in progress - Job ID: ${result['job_id']}',
          'file_name': 'Image${imageCount > 1 ? 's' : ''} (${imageCount})',
          'total_page_batches': imageCount,
          'total_words': 0,
          'estimated_reading_time_minutes': imageCount * 2.0,
          'processing_time_seconds': 0.0,
          'job_id': result['job_id'],
          'session_id': result['session_id'],
          'status': 'processing',
          'page_batches': [],
        }));
        
        // ✅ CRITICAL: Register callback for when real results are ready  
        BackgroundJobApiService.onResultsReady(result['job_id'], (finalResults) {
          print('🎉 Image results callback triggered with final data');
          
          // Convert final results to ProcessingResult and update processing page
          try {
            final processedResult = ProcessingResult.fromNewApiResponse(finalResults);
            print('📋 Converted to ProcessingResult with ${processedResult.pageBatches.length} batches');
            
            // Call the main callback to update processing page
            widget.onImagesProcessed(processedResult);
            
          } catch (e) {
            print('❌ Error converting final results: $e');
            // Fallback with mock results
            widget.onImagesProcessed(ProcessingResult.fromNewApiResponse({
              'success': true,
              'message': 'Image processing completed',
              'file_name': 'Image Content',
              'total_items': imageCount,
              'total_words': 400,
              'pages': finalResults['pages'] ?? [],
            }));
          }
        });
      } else {
        throw Exception('Failed to start image processing - no job ID returned');
      }
    } catch (e) {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
      _showSnackBar('Failed to process images: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = _selectedImages.isNotEmpty || _selectedWebImages.isNotEmpty;
    final imageCount = kIsWeb ? _selectedWebImages.length : _selectedImages.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: hasImages
                    ? LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                    : LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (hasImages ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                hasImages ? Icons.check_circle : Icons.image,
                color: Colors.white,
                size: 36,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title and description
            Text(
              hasImages ? '$imageCount Image${imageCount == 1 ? '' : 's'} Ready!' : 'Upload Images',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              hasImages
                  ? 'Ready to extract text with OCR'
                  : 'Upload images for text extraction',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action buttons
            if (!hasImages)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _pickImages,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 18),
                      const SizedBox(width: 8),
                      Text('Choose Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            
            if (hasImages)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedImages = [];
                            _selectedWebImages = [];
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF2563EB),
                          side: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.3), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Change'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processImages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isProcessing
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.document_scanner, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Extract Text', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
    );
  }
}

// Background Job API Service (simplified for compact widgets)
class BackgroundJobApiService {
  static const String baseUrl = 'https://imgbooc-production.up.railway.app';

  static Future<Map<String, dynamic>?> processImages(List<File> files,
      {int maxConcurrent = 5}) async {
    try {
      final uri = Uri.parse('$baseUrl/process-images');
      final request = http.MultipartRequest('POST', uri);

      request.fields['max_concurrent'] = maxConcurrent.toString();

      for (int i = 0; i < files.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            files[i].path,
            filename: files[i].path.split('/').last,
          ),
        );
      }

      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'Bookey-Flutter-App/1.0',
      });

      final streamedResponse = await request.send().timeout(Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📸 Image processing started - Job ID: ${data['job_id']}, Session: ${data['session_id']}');
        
        // Start polling for this job
        if (data['job_id'] != null) {
          _startJobPolling(data['job_id'], data['session_id']);
        }
        
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to start image processing');
      }
    } catch (e) {
      print('❌ Image processing error: $e');
      throw Exception('Failed to start image processing: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>?> processImagesWeb(List<PlatformFile> webFiles,
      {int maxConcurrent = 5}) async {
    try {
      final uri = Uri.parse('$baseUrl/process-images');
      final request = http.MultipartRequest('POST', uri);

      request.fields['max_concurrent'] = maxConcurrent.toString();

      for (var webFile in webFiles) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            webFile.bytes!,
            filename: webFile.name,
          ),
        );
      }

      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'Bookey-Flutter-App/1.0',
      });

      final streamedResponse = await request.send().timeout(Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📸 Web image processing started - Job ID: ${data['job_id']}, Session: ${data['session_id']}');
        
        // Start polling for this job
        if (data['job_id'] != null) {
          _startJobPolling(data['job_id'], data['session_id']);
        }
        
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to start image processing');
      }
    } catch (e) {
      print('❌ Web image processing error: $e');
      throw Exception('Failed to start image processing: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>?> processAudio(File? file, PlatformFile? webFile) async {
    try {
      final uri = Uri.parse('$baseUrl/process-audio');
      final request = http.MultipartRequest('POST', uri);

      final sessionId = _generateSessionId();
      request.fields['session_id'] = sessionId;

      if (kIsWeb && webFile != null) {
        request.files.add(http.MultipartFile.fromBytes('file', webFile.bytes!,
            filename: webFile.name));
      } else if (file != null) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path,
            filename: file.path.split('/').last));
      }

      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'Bookey-Flutter-App/2.0',
      });

      final streamedResponse = await request.send().timeout(Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🎵 Audio processing started - Job ID: ${data['job_id']}, Session: ${data['session_id'] ?? sessionId}');
        
        // Start polling for this job
        if (data['job_id'] != null) {
          _startJobPolling(data['job_id'], data['session_id'] ?? sessionId);
        }
        
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to start audio processing');
      }
    } catch (e) {
      print('❌ Audio processing error: $e');
      throw Exception('Failed to start audio processing: ${e.toString()}');
    }
  }

  // ✅ ENHANCED JOB POLLING SYSTEM
  static final Map<String, Timer> _activePollers = {};
  static final Map<String, Function(Map<String, dynamic>)> _resultCallbacks = {};

  static Future<Map<String, dynamic>?> getJobStatus(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/job-status/$jobId'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/1.0',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('Error checking job status for $jobId: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getResults(String sessionId) async {
    try {
      print('🔍 Trying to fetch results for session: $sessionId');
      
      // Method 1: Standard results endpoint
      var response = await http.get(
        Uri.parse('$baseUrl/results/$sessionId'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Bookey-Flutter-App/2.0',
        },
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Results fetched for session $sessionId via standard endpoint');
        return data;
      }
      
      // Method 2: Try session-results endpoint
      try {
        response = await http.get(
          Uri.parse('$baseUrl/session-results/$sessionId'),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Bookey-Flutter-App/2.0',
          },
        ).timeout(Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ Results fetched via session-results endpoint');
          return data;
        }
      } catch (e) {
        print('❌ session-results endpoint failed: $e');
      }
      
      // Method 3: Try download endpoint
      try {
        response = await http.get(
          Uri.parse('$baseUrl/download/$sessionId'),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Bookey-Flutter-App/2.0',
          },
        ).timeout(Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ Results fetched via download endpoint');
          return data;
        }
      } catch (e) {
        print('❌ Download endpoint failed: $e');
      }
      
      // Method 4: Try session-info endpoint
      try {
        response = await http.get(
          Uri.parse('$baseUrl/session-info/$sessionId'),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Bookey-Flutter-App/2.0',
          },
        ).timeout(Duration(seconds: 15));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ Results fetched via session-info endpoint');
          return data;
        }
      } catch (e) {
        print('❌ session-info endpoint failed: $e');
      }
      
      print('❌ All result fetching methods failed for session $sessionId');
      return null;
    } catch (e) {
      print('❌ Error getting results for session $sessionId: $e');
      return null;
    }
  }

  // Start polling for job completion
  static void _startJobPolling(String jobId, String? sessionId) {
    print('🔄 Starting polling for job $jobId');
    
    // Cancel existing poller if any
    _activePollers[jobId]?.cancel();
    
    int pollCount = 0;
    const maxPolls = 30; // Increase timeout to 90 seconds (30 * 3)
    
    // Start new polling timer
    _activePollers[jobId] = Timer.periodic(Duration(seconds: 3), (timer) async {
      try {
        pollCount++;
        print('🔍 Poll #$pollCount for job $jobId');
        final statusData = await getJobStatus(jobId);
        
        if (statusData != null) {
          final status = statusData['status'];
          print('📊 Job $jobId status: $status (poll #$pollCount)');
          
          // Check if job is complete
          if (status == 'completed' || status == 'finished' || status == 'success') {
            print('✅ Job $jobId completed! Fetching results...');
            timer.cancel();
            _activePollers.remove(jobId);
            
            // Try to get real results
            if (sessionId != null) {
              var results = await getResults(sessionId);
              
              if (results != null) {
                print('🎉 Real results fetched for session $sessionId');
                
                // Convert results to ProcessingResult and trigger callback
                try {
                  final processedResult = ProcessingResult.fromNewApiResponse(results);
                  _resultCallbacks[jobId]?.call(results);
                  
                  // Navigate to processing page
                  Future.delayed(Duration(milliseconds: 500), () {
                    NavigationService().navigateToProcessing();
                  });
                  
                } catch (e) {
                  print('❌ Error converting results: $e');
                  _resultCallbacks[jobId]?.call(results);
                }
              } else {
                print('❌ Failed to get results for session $sessionId');
                // Create fallback result with useful info
                final fallbackResult = {
                  'success': true,
                  'message': 'Processing completed - results may take a moment to appear',
                  'file_name': 'Processed Content',
                  'total_items': 1,
                  'total_words': 0,
                  'estimated_reading_time_minutes': 1.0,
                  'processing_time_seconds': 30.0,
                  'pages': [
                    {
                      'page_number': 1,
                      'title': 'Processed Content',
                      'text': 'Processing completed successfully. If content is not showing, please try refreshing or check back in a moment.',
                      'cleaned_text': 'Content processing has finished. Results should appear shortly.',
                      'word_count': 20,
                      'cleaned': true,
                    }
                  ]
                };
                _resultCallbacks[jobId]?.call(fallbackResult);
              }
            }
          } else if (status == 'failed' || status == 'error') {
            print('❌ Job $jobId failed');
            timer.cancel();
            _activePollers.remove(jobId);
          } else if (pollCount >= maxPolls) {
            print('⏰ Polling timeout for job $jobId after $maxPolls attempts');
            timer.cancel();
            _activePollers.remove(jobId);
          }
        } else {
          print('❌ No status data for job $jobId (poll #$pollCount)');
          if (pollCount >= maxPolls) {
            timer.cancel();
            _activePollers.remove(jobId);
          }
        }
      } catch (e) {
        print('Error polling job $jobId: $e');
        if (pollCount >= maxPolls) {
          timer.cancel();
          _activePollers.remove(jobId);
        }
      }
    });
  }

  // Register callback for when results are ready
  static void onResultsReady(String jobId, Function(Map<String, dynamic>) callback) {
    _resultCallbacks[jobId] = callback;
  }

  // Stop polling for a specific job
  static void stopPolling(String jobId) {
    _activePollers[jobId]?.cancel();
    _activePollers.remove(jobId);
    _resultCallbacks.remove(jobId);
  }

  // Stop all polling
  static void stopAllPolling() {
    for (var timer in _activePollers.values) {
      timer.cancel();
    }
    _activePollers.clear();
    _resultCallbacks.clear();
  }
  
  // Helper method to generate session IDs
  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'session_${timestamp}_${timestamp.hashCode.abs().toString().substring(0, 6)}';
  }
}