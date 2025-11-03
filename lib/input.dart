import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'api_service.dart';

// Story Generator Widget (unchanged - working correctly)
class StoryGeneratorWidget extends StatefulWidget {
  final Function(ProcessingResult) onStoryGenerated;

  const StoryGeneratorWidget({super.key, required this.onStoryGenerated});

  @override
  State<StoryGeneratorWidget> createState() => _StoryGeneratorWidgetState();
}

class _StoryGeneratorWidgetState extends State<StoryGeneratorWidget>
    with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _charactersController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();

  String _selectedGenre = 'Fantasy';
  String _selectedDuration = 'Medium (10-20 minutes read)';
  bool _isGenerating = false;
  int _wordCount = 0;

  // Staged loading state
  bool _showStagedLoading = false;
  int _currentStage = 0;
  final List<String> _storyStages = [
    'Analyzing your story requirements',
    'Generating creative content with AI',
    'Structuring and formatting story',
    'Finalizing your masterpiece'
  ];

  List<Map<String, String>> _genres = [
    {'value': 'Action/Adventure', 'label': 'Action/Adventure'},
    {'value': 'Comedy', 'label': 'Comedy'},
    {'value': 'Drama', 'label': 'Drama'},
    {'value': 'Fantasy', 'label': 'Fantasy'},
    {'value': 'Historical', 'label': 'Historical'},
    {'value': 'Horror', 'label': 'Horror'},
    {'value': 'Mystery Crime Thriller', 'label': 'Mystery Crime Thriller'},
    {'value': 'Romance', 'label': 'Romance'},
    {'value': 'Science Fiction', 'label': 'Science Fiction'},
  ];

  List<Map<String, String>> _durations = [
    {
      'value': 'Short (5-10 minutes read)',
      'label': 'Short (5-10 minutes read)'
    },
    {
      'value': 'Medium (10-20 minutes read)',
      'label': 'Medium (10-20 minutes read)'
    },
    {
      'value': 'Long (20-30 minutes read)',
      'label': 'Long (20-30 minutes read)'
    },
    {'value': 'Epic (30+ minutes read)', 'label': 'Epic (30+ minutes read)'},
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();

    _subjectController.addListener(_updateWordCount);
    _charactersController.addListener(_updateWordCount);
    _contextController.addListener(_updateWordCount);

    _selectedGenre = 'Fantasy';
    _selectedDuration = 'Medium (10-20 minutes read)';

    _loadGenresAndDurations();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _charactersController.dispose();
    _contextController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final totalText =
        '${_subjectController.text} ${_charactersController.text} ${_contextController.text}';
    final words = totalText.trim().isEmpty
        ? 0
        : totalText.trim().split(RegExp(r'\s+')).length;
    if (words != _wordCount) {
      setState(() {
        _wordCount = words;
      });
    }
  }

  String _getSafeGenreValue() {
    return _genres.any((genre) => genre['value'] == _selectedGenre)
        ? _selectedGenre
        : 'Fantasy';
  }

  String _getSafeDurationValue() {
    return _durations.any((duration) => duration['value'] == _selectedDuration)
        ? _selectedDuration
        : 'Medium (10-20 minutes read)';
  }

  Future<void> _loadGenresAndDurations() async {
    try {
      final genres = await ApiService.getAvailableGenres();
      if (genres.isNotEmpty) {
        setState(() {
          _genres = genres;
          if (!_genres.any((g) => g['value'] == _selectedGenre)) {
            _selectedGenre = _genres.first['value']!;
          }
        });
      }

      final durations = await ApiService.getAvailableDurations();
      if (durations.isNotEmpty) {
        setState(() {
          _durations = durations;
          if (!_durations.any((d) => d['value'] == _selectedDuration)) {
            _selectedDuration = _durations.first['value']!;
          }
        });
      }
    } catch (e) {
      // Keep defaults if API fails
    }
  }

  Future<void> _generateStory() async {
    if (!_canGenerateStory()) {
      _showSnackBar('Please complete the required fields', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _showStagedLoading = true;
      _currentStage = 0;
    });

    // Start the staged loading animation
    _startStagedLoading();

    try {
      final storyRequest = StoryRequest(
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        characters: _charactersController.text.trim().isEmpty
            ? null
            : _charactersController.text.trim(),
        context: _contextController.text.trim().isEmpty
            ? null
            : _contextController.text.trim(),
        duration: _selectedDuration,
        genre: _selectedGenre,
      );

      final result = await ApiService.generateStory(storyRequest);

      if (result.success) {
        // Complete all stages
        await _completeAllStages();
        
        widget.onStoryGenerated(result);
        _showSnackBar('Story generated successfully! Navigating to Processing...', isError: false);
        _clearForm();
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      _showSnackBar('Generation failed: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isGenerating = false;
        _showStagedLoading = false;
        _currentStage = 0;
      });
    }
  }

  void _startStagedLoading() {
    Timer.periodic(Duration(milliseconds: 800), (timer) {
      if (!_showStagedLoading || _currentStage >= _storyStages.length) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _currentStage++;
      });
    });
  }

  Future<void> _completeAllStages() async {
    while (_currentStage < _storyStages.length) {
      await Future.delayed(Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _currentStage++;
        });
      }
    }
    await Future.delayed(Duration(milliseconds: 500)); // Final pause before navigation
  }

  void _clearForm() {
    _titleController.clear();
    _subjectController.clear();
    _charactersController.clear();
    _contextController.clear();
    setState(() {
      _wordCount = 0;
    });
  }

  bool _canGenerateStory() {
    return _titleController.text.trim().isNotEmpty &&
        _subjectController.text.trim().isNotEmpty;
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3F0), // Beige background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE8E3DD),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (_showStagedLoading)
                StagedLoadingWidget(
                  stages: _storyStages,
                  currentStage: _currentStage,
                  title: 'Creating Your Story',
                  icon: Icons.auto_awesome,
                  primaryColor: const Color(0xFF6366F1),
                )
              else ...[
                _buildFormLayout(),
                const SizedBox(height: 20),
                _buildGenerateSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Story Creator',
                style: TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Generate engaging stories with AI',
                style: TextStyle(
                  color: Color(0xFF8B7355),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormLayout() {
    return Column(
      children: [
        _buildFormField(
          controller: _titleController,
          label: 'Story Title',
          placeholder: 'Enter a compelling title...',
          isRequired: true,
        ),
        const SizedBox(height: 16),
        _buildFormField(
          controller: _subjectController,
          label: 'Main Subject/Plot',
          placeholder: 'What is your story about...',
          isRequired: true,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                value: _selectedGenre,
                label: 'Genre',
                items: _genres,
                onChanged: (value) {
                  setState(() {
                    _selectedGenre = value!;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField(
                value: _selectedDuration,
                label: 'Duration',
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
        _buildFormField(
          controller: _charactersController,
          label: 'Characters (Optional)',
          placeholder: 'Describe main characters...',
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _buildFormField(
          controller: _contextController,
          label: 'Additional Context (Optional)',
          placeholder: 'Any specific setting, themes, or details...',
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF2D2D2D),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE8E3DD),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              color: Color(0xFF2D2D2D),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                color: const Color(0xFF8B7355).withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required List<Map<String, String>> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF2D2D2D),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE8E3DD),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: const TextStyle(
              color: Color(0xFF2D2D2D),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            dropdownColor: Colors.white,
            isExpanded: true, // Fix overflow by expanding dropdown
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item['value'],
                child: Text(
                  item['label']!,
                  style: const TextStyle(
                    color: Color(0xFF2D2D2D),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateSection() {
    return Column(
      children: [
        if (_wordCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF8B7355).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_wordCount words provided',
              style: const TextStyle(
                color: Color(0xFF8B7355),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2D2D2D).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _canGenerateStory() && !_isGenerating ? _generateStory : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D2D2D),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFF3F4F6),
              disabledForegroundColor: const Color(0xFF9CA3AF),
              elevation: 0,
              shadowColor: Colors.transparent,
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
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 18),
                      SizedBox(width: 8),
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
    );
  }
}

// STAGED LOADING WIDGET - The star of the show! 🌟
class StagedLoadingWidget extends StatefulWidget {
  final List<String> stages;
  final int currentStage;
  final String title;
  final IconData icon;
  final Color primaryColor;

  const StagedLoadingWidget({
    super.key,
    required this.stages,
    required this.currentStage,
    required this.title,
    required this.icon,
    required this.primaryColor,
  });

  @override
  State<StagedLoadingWidget> createState() => _StagedLoadingWidgetState();
}

class _StagedLoadingWidgetState extends State<StagedLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _checkController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StagedLoadingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentStage > oldWidget.currentStage) {
      _checkController.forward().then((_) {
        _checkController.reset();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.primaryColor.withOpacity(0.1),
            widget.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header with animated icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: widget.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            'Please wait while we process your request...',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF8B7355).withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Progress stages
          Column(
            children: List.generate(widget.stages.length, (index) {
              final isCompleted = index < widget.currentStage;
              final isCurrent = index == widget.currentStage - 1;
              final isPending = index >= widget.currentStage;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    // Step indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? const Color(0xFF10B981)
                            : isCurrent 
                                ? widget.primaryColor
                                : const Color(0xFFE5E7EB),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted 
                              ? const Color(0xFF10B981)
                              : isCurrent 
                                  ? widget.primaryColor
                                  : const Color(0xFFD1D5DB),
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? ScaleTransition(
                              scale: _checkAnimation,
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            )
                          : isCurrent
                              ? SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9CA3AF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Step text
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCompleted || isCurrent 
                              ? FontWeight.w600 
                              : FontWeight.w400,
                          color: isCompleted
                              ? const Color(0xFF10B981)
                              : isCurrent
                                  ? widget.primaryColor
                                  : const Color(0xFF9CA3AF),
                        ),
                        child: Text(widget.stages[index]),
                      ),
                    ),
                    
                    // Completion indicator
                    if (isCompleted)
                      ScaleTransition(
                        scale: _checkAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          
          const SizedBox(height: 24),
          
          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widget.currentStage / widget.stages.length,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.primaryColor, const Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Progress text
          Text(
            '${widget.currentStage}/${widget.stages.length} steps completed',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: widget.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// AUDIO UPLOAD WIDGET with Staged Loading
class AudioUploadWidget extends StatefulWidget {
  final Function(ProcessingResult) onAudioProcessed;

  const AudioUploadWidget({super.key, required this.onAudioProcessed});

  @override
  State<AudioUploadWidget> createState() => _AudioUploadWidgetState();
}

class _AudioUploadWidgetState extends State<AudioUploadWidget>
    with TickerProviderStateMixin {
  File? _selectedFile;
  PlatformFile? _selectedWebFile;
  bool _isProcessing = false;
  bool _isPickingFile = false;
  Timer? _jobPollingTimer;
  String? _currentJobId;
  bool _requestInProgress = false;
  
  // Staged loading state
  bool _showStagedLoading = false;
  int _currentStage = 0;
  final List<String> _audioStages = [
    'Uploading audio file to cloud',
    'Transcribing with AssemblyAI',
    'Cleaning text with AI',
    'Finalizing transcription'
  ];
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _jobPollingTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    if (_isPickingFile) {
      print('Audio file picker already in progress, ignoring request');
      return;
    }

    setState(() {
      _isPickingFile = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
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
      print('Error selecting audio file: $e');
      if (!e.toString().contains('multiple_request') && !e.toString().contains('User cancelled')) {
        _showSnackBar('Error selecting audio file: $e', isError: true);
      }
    } finally {
      setState(() {
        _isPickingFile = false;
      });
    }
  }

  Future<void> _processAudio() async {
    if (_selectedFile == null && _selectedWebFile == null) {
      _showSnackBar('Please select an audio file first', isError: true);
      return;
    }

    if (_requestInProgress) {
      print('Audio processing request already in progress, ignoring');
      return;
    }

    setState(() {
      _requestInProgress = true;
      _isProcessing = true;
      _showStagedLoading = true;
      _currentStage = 0;
    });

    // Start the staged loading animation
    _startStagedLoading();

    try {
      final jobInfo = await BackgroundJobApiService.processAudio(
        _selectedFile, 
        _selectedWebFile,
      );

      if (jobInfo != null && jobInfo['success'] == true) {
        _currentJobId = jobInfo['job_id'];
        _showSnackBar('Audio processing started! Monitoring progress...', isError: false);
        _startJobPolling();
      } else {
        throw Exception(jobInfo?['message'] ?? 'Failed to start audio processing');
      }
    } catch (e) {
      _showSnackBar('Failed to start audio processing: ${e.toString()}', isError: true);
      setState(() {
        _isProcessing = false;
        _showStagedLoading = false;
        _requestInProgress = false;
        _currentStage = 0;
      });
    }
  }

  void _startStagedLoading() {
    Timer.periodic(Duration(seconds: 2), (timer) {
      if (!_showStagedLoading || _currentStage >= _audioStages.length) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _currentStage++;
      });
    });
  }

  void _startJobPolling() {
    if (_currentJobId == null) return;
    
    _jobPollingTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        final status = await BackgroundJobApiService.getJobStatus(_currentJobId!);
        
        if (status != null) {
          if (status['status'] == 'completed') {
            timer.cancel();
            await _handleJobCompletion(status);
          } else if (status['status'] == 'failed') {
            timer.cancel();
            _handleJobFailure(status);
          }
        }
      } catch (e) {
        print('Error polling job status: $e');
      }
    });
  }

  Future<void> _handleJobCompletion(Map<String, dynamic> status) async {
    try {
      // Complete all stages quickly
      await _completeAllStages();
      
      final result = status['result'];
      if (result != null) {
        final processingResult = _convertJobResultToProcessingResult(result);
        widget.onAudioProcessed(processingResult);
        _showSnackBar('Audio processed successfully! Navigating to Processing...', isError: false);
        
        setState(() {
          _selectedFile = null;
          _selectedWebFile = null;
          _isProcessing = false;
          _showStagedLoading = false;
          _currentJobId = null;
          _requestInProgress = false;
          _currentStage = 0;
        });
      } else {
        final sessionId = status['session_id'];
        if (sessionId != null) {
          final results = await BackgroundJobApiService.getResults(sessionId);
          if (results != null) {
            final processingResult = _convertJobResultToProcessingResult(results);
            widget.onAudioProcessed(processingResult);
            _showSnackBar('Audio processed successfully! Navigating to Processing...', isError: false);
            
            setState(() {
              _selectedFile = null;
              _selectedWebFile = null;
              _isProcessing = false;
              _showStagedLoading = false;
              _currentJobId = null;
              _requestInProgress = false;
              _currentStage = 0;
            });
          }
        }
      }
    } catch (e) {
      _handleJobFailure({'error_message': e.toString()});
    }
  }

  Future<void> _completeAllStages() async {
    while (_currentStage < _audioStages.length) {
      await Future.delayed(Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _currentStage++;
        });
      }
    }
    await Future.delayed(Duration(milliseconds: 500));
  }

  void _handleJobFailure(Map<String, dynamic> status) {
    final errorMessage = status['error_message'] ?? 'Unknown error occurred';
    _showSnackBar('Audio processing failed: $errorMessage', isError: true);
    
    setState(() {
      _isProcessing = false;
      _showStagedLoading = false;
      _currentJobId = null;
      _requestInProgress = false;
      _currentStage = 0;
    });
  }

  ProcessingResult _convertJobResultToProcessingResult(Map<String, dynamic> result) {
    List<PageBatchModel> pageBatches = [];
    
    if (result['parts'] != null) {
      for (var part in result['parts']) {
        pageBatches.add(PageBatchModel(
          batchNumber: part['part_number'] ?? 1,
          pageRange: "Part ${part['part_number'] ?? 1}",
          cleanedText: part['cleaned_text'] ?? part['text'] ?? '',
          wordCount: part['word_count'] ?? 0,
          cleaned: part['cleaned'] ?? false,
          pagesInBatch: 1,
        ));
      }
    }

    return ProcessingResult(
      success: result['success'] ?? true,
      message: result['message'] ?? 'Audio processing completed',
      fileName: result['file_name'] ?? 'Audio Transcription',
      totalPageBatches: result['total_items'] ?? pageBatches.length,
      totalWords: result['total_words'] ?? 0,
      estimatedReadingTimeMinutes: result['estimated_reading_time_minutes'] ?? 0.0,
      pageBatches: pageBatches,
      processingTimeSeconds: result['processing_time_seconds'] ?? 0.0,
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor:
              isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _selectedFile != null || _selectedWebFile != null;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFF0FDF4) : const Color(0xFFF5F3F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? const Color(0xFF10B981).withOpacity(0.3)
                : const Color(0xFFE8E3DD),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showStagedLoading)
              StagedLoadingWidget(
                stages: _audioStages,
                currentStage: _currentStage,
                title: 'Processing Audio',
                icon: Icons.audiotrack,
                primaryColor: const Color(0xFF3B82F6),
              )
            else ...[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: hasFile ? const Color(0xFF10B981) : const Color(0xFF8B7355),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (hasFile
                              ? const Color(0xFF10B981)
                              : const Color(0xFF8B7355))
                          .withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  hasFile ? Icons.check_circle : Icons.audiotrack,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasFile ? 'Audio File Selected!' : 'Upload Audio',
                style: const TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasFile
                    ? 'Ready for AssemblyAI transcription'
                    : 'Upload audio for AI transcription',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8B7355),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              if (!hasFile)
                _buildActionButton(
                  text: _isPickingFile ? 'Selecting...' : 'Choose Audio File',
                  icon: _isPickingFile ? null : Icons.upload_file,
                  onPressed: _isPickingFile ? null : _pickAudioFile,
                  isPrimary: true,
                  isLoading: _isPickingFile,
                ),
              if (hasFile) ...[
                _buildSelectedFileCard(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        text: 'Change File',
                        icon: Icons.swap_horiz,
                        onPressed: _isProcessing ? null : () {
                          _jobPollingTimer?.cancel();
                          setState(() {
                            _selectedFile = null;
                            _selectedWebFile = null;
                            _isProcessing = false;
                            _showStagedLoading = false;
                            _currentJobId = null;
                            _requestInProgress = false;
                            _currentStage = 0;
                          });
                        },
                        isPrimary: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildActionButton(
                        text: _isProcessing ? 'Processing...' : 'Process Audio',
                        icon: _isProcessing ? null : Icons.auto_awesome,
                        onPressed: _isProcessing ? null : _processAudio,
                        isPrimary: true,
                        isLoading: _isProcessing,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard() {
    final fileName = kIsWeb
        ? (_selectedWebFile?.name ?? 'Audio File')
        : (_selectedFile?.path.split('/').last ?? 'Audio File');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.audiotrack,
              color: Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Color(0xFF2D2D2D),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ready for AssemblyAI transcription',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    IconData? icon,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: const Color(0xFF2D2D2D).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? const Color(0xFF2D2D2D) : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : const Color(0xFF8B7355),
          disabledBackgroundColor:
              isPrimary ? const Color(0xFFF3F4F6) : Colors.transparent,
          disabledForegroundColor: const Color(0xFF9CA3AF),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: isPrimary
              ? null
              : const BorderSide(
                  color: Color(0xFFE8E3DD),
                  width: 1,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Enhanced Camera Widget with Staged Loading
class EnhancedCameraWidget extends StatefulWidget {
  final Function(ProcessingResult) onImagesProcessed;

  const EnhancedCameraWidget({super.key, required this.onImagesProcessed});

  @override
  State<EnhancedCameraWidget> createState() => _EnhancedCameraWidgetState();
}

class _EnhancedCameraWidgetState extends State<EnhancedCameraWidget>
    with TickerProviderStateMixin {
  List<File> _selectedImages = [];
  List<PlatformFile> _selectedWebImages = [];
  bool _isProcessing = false;
  bool _isPickingImages = false;
  Timer? _jobPollingTimer;
  String? _currentJobId;
  bool _requestInProgress = false;
  
  // Staged loading state
  bool _showStagedLoading = false;
  int _currentStage = 0;
  final List<String> _imageStages = [
    'Uploading images to cloud',
    'Extracting text with OCR',
    'Cleaning text with AI',
    'Finalizing results'
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _jobPollingTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isPickingImages) {
      print('Image picker already in progress, ignoring request');
      return;
    }

    setState(() {
      _isPickingImages = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _selectedWebImages = result.files;
            _selectedImages = [];
          } else {
            _selectedImages = result.paths.map((path) => File(path!)).toList();
            _selectedWebImages = [];
          }
        });

        final count = kIsWeb ? _selectedWebImages.length : _selectedImages.length;
        _showSnackBar('$count image(s) selected successfully!', isError: false);
      }
    } catch (e) {
      if (!e.toString().contains('multiple_request') && !e.toString().contains('User cancelled')) {
        _showSnackBar('Error selecting images: $e', isError: true);
      }
    } finally {
      setState(() {
        _isPickingImages = false;
      });
    }
  }

  Future<void> _processImages() async {
    if (_selectedImages.isEmpty && _selectedWebImages.isEmpty) {
      _showSnackBar('Please select images first', isError: true);
      return;
    }

    if (_requestInProgress) {
      print('Image processing request already in progress, ignoring');
      return;
    }

    setState(() {
      _requestInProgress = true;
      _isProcessing = true;
      _showStagedLoading = true;
      _currentStage = 0;
    });

    // Start the staged loading animation
    _startStagedLoading();

    try {
      Map<String, dynamic>? jobInfo;
      
      if (kIsWeb) {
        jobInfo = await BackgroundJobApiService.processImagesWeb(
          _selectedWebImages,
          maxConcurrent: 5,
        );
      } else {
        jobInfo = await BackgroundJobApiService.processImages(
          _selectedImages,
          maxConcurrent: 5,
        );
      }

      if (jobInfo != null && jobInfo['success'] == true) {
        _currentJobId = jobInfo['job_id'];
        _showSnackBar('Image processing started! Monitoring progress...', isError: false);
        _startJobPolling();
      } else {
        throw Exception(jobInfo?['message'] ?? 'Failed to start image processing');
      }
    } catch (e) {
      _showSnackBar('Failed to start image processing: ${e.toString()}', isError: true);
      setState(() {
        _isProcessing = false;
        _showStagedLoading = false;
        _requestInProgress = false;
        _currentStage = 0;
      });
    }
  }

  void _startStagedLoading() {
    Timer.periodic(Duration(seconds: 2), (timer) {
      if (!_showStagedLoading || _currentStage >= _imageStages.length) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _currentStage++;
      });
    });
  }

  void _startJobPolling() {
    if (_currentJobId == null) return;
    
    _jobPollingTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      try {
        final status = await BackgroundJobApiService.getJobStatus(_currentJobId!);
        
        if (status != null) {
          if (status['status'] == 'completed') {
            timer.cancel();
            await _handleJobCompletion(status);
          } else if (status['status'] == 'failed') {
            timer.cancel();
            _handleJobFailure(status);
          }
        }
      } catch (e) {
        print('Error polling job status: $e');
      }
    });
  }

  Future<void> _handleJobCompletion(Map<String, dynamic> status) async {
    try {
      // Complete all stages
      await _completeAllStages();
      
      final result = status['result'];
      if (result != null) {
        final processingResult = _convertJobResultToProcessingResult(result);
        widget.onImagesProcessed(processingResult);
        _showSnackBar('Images processed successfully! Navigating to Processing...', isError: false);
        
        setState(() {
          _selectedImages = [];
          _selectedWebImages = [];
          _isProcessing = false;
          _showStagedLoading = false;
          _currentJobId = null;
          _requestInProgress = false;
          _currentStage = 0;
        });
      } else {
        final sessionId = status['session_id'];
        if (sessionId != null) {
          final results = await BackgroundJobApiService.getResults(sessionId);
          if (results != null) {
            final processingResult = _convertJobResultToProcessingResult(results);
            widget.onImagesProcessed(processingResult);
            _showSnackBar('Images processed successfully! Navigating to Processing...', isError: false);
            
            setState(() {
              _selectedImages = [];
              _selectedWebImages = [];
              _isProcessing = false;
              _showStagedLoading = false;
              _currentJobId = null;
              _requestInProgress = false;
              _currentStage = 0;
            });
          }
        }
      }
    } catch (e) {
      _handleJobFailure({'error_message': e.toString()});
    }
  }

  Future<void> _completeAllStages() async {
    while (_currentStage < _imageStages.length) {
      await Future.delayed(Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _currentStage++;
        });
      }
    }
    await Future.delayed(Duration(milliseconds: 500));
  }

  void _handleJobFailure(Map<String, dynamic> status) {
    final errorMessage = status['error_message'] ?? 'Unknown error occurred';
    _showSnackBar('Image processing failed: $errorMessage', isError: true);
    
    setState(() {
      _isProcessing = false;
      _showStagedLoading = false;
      _currentJobId = null;
      _requestInProgress = false;
      _currentStage = 0;
    });
  }

  ProcessingResult _convertJobResultToProcessingResult(Map<String, dynamic> result) {
    List<PageBatchModel> pageBatches = [];
    
    if (result['pages'] != null) {
      for (var page in result['pages']) {
        pageBatches.add(PageBatchModel(
          batchNumber: page['page_number'] ?? 1,
          pageRange: (page['page_number'] ?? 1).toString(),
          cleanedText: page['cleaned_text'] ?? page['text'] ?? '',
          wordCount: page['word_count'] ?? 0,
          cleaned: page['cleaned'] ?? false,
          pagesInBatch: 1,
        ));
      }
    }

    return ProcessingResult(
      success: result['success'] ?? true,
      message: result['message'] ?? 'Image processing completed',
      fileName: result['file_name'] ?? 'Image Processing',
      totalPageBatches: result['total_items'] ?? pageBatches.length,
      totalWords: result['total_words'] ?? 0,
      estimatedReadingTimeMinutes: result['estimated_reading_time_minutes'] ?? 0.0,
      pageBatches: pageBatches,
      processingTimeSeconds: result['processing_time_seconds'] ?? 0.0,
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor:
              isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = _selectedImages.isNotEmpty || _selectedWebImages.isNotEmpty;
    final imageCount = kIsWeb ? _selectedWebImages.length : _selectedImages.length;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasImages ? const Color(0xFFF0FDF4) : const Color(0xFFF5F3F0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImages
                ? const Color(0xFF10B981).withOpacity(0.3)
                : const Color(0xFFE8E3DD),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showStagedLoading)
              StagedLoadingWidget(
                stages: _imageStages,
                currentStage: _currentStage,
                title: 'Processing Images',
                icon: Icons.image,
                primaryColor: const Color(0xFF10B981),
              )
            else ...[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: hasImages ? const Color(0xFF10B981) : const Color(0xFF8B7355),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (hasImages
                              ? const Color(0xFF10B981)
                              : const Color(0xFF8B7355))
                          .withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  hasImages ? Icons.check_circle : Icons.image,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasImages ? '$imageCount Image(s) Selected!' : 'Upload Images',
                style: const TextStyle(
                  color: Color(0xFF2D2D2D),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasImages
                    ? 'Ready to extract text with AI OCR'
                    : 'Upload images for AI text extraction',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8B7355),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              if (!hasImages)
                _buildActionButton(
                  text: _isPickingImages ? 'Selecting...' : 'Choose Images',
                  icon: _isPickingImages ? null : Icons.upload_file,
                  onPressed: _isPickingImages ? null : _pickImages,
                  isPrimary: true,
                  isLoading: _isPickingImages,
                ),
              if (hasImages) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        text: 'Change Images',
                        icon: Icons.swap_horiz,
                        onPressed: _isProcessing ? null : () {
                          _jobPollingTimer?.cancel();
                          setState(() {
                            _selectedImages = [];
                            _selectedWebImages = [];
                            _isProcessing = false;
                            _showStagedLoading = false;
                            _currentJobId = null;
                            _requestInProgress = false;
                            _currentStage = 0;
                          });
                        },
                        isPrimary: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildActionButton(
                        text: _isProcessing ? 'Processing...' : 'Extract Text',
                        icon: _isProcessing ? null : Icons.document_scanner,
                        onPressed: _isProcessing ? null : _processImages,
                        isPrimary: true,
                        isLoading: _isProcessing,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    IconData? icon,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: const Color(0xFF2D2D2D).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? const Color(0xFF2D2D2D) : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : const Color(0xFF8B7355),
          disabledBackgroundColor:
              isPrimary ? const Color(0xFFF3F4F6) : Colors.transparent,
          disabledForegroundColor: const Color(0xFF9CA3AF),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: isPrimary
              ? null
              : const BorderSide(
                  color: Color(0xFFE8E3DD),
                  width: 1,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// BACKGROUND JOB API SERVICE (same as before but included for completeness)
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
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to start image processing');
      }
    } catch (e) {
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
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to start image processing');
      }
    } catch (e) {
      throw Exception('Failed to start image processing: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>?> processAudio(File? file, PlatformFile? webFile) async {
    try {
      final uri = Uri.parse('$baseUrl/process-audio');
      final request = http.MultipartRequest('POST', uri);

      if (kIsWeb && webFile != null) {
        request.files.add(http.MultipartFile.fromBytes('file', webFile.bytes!,
            filename: webFile.name));
      } else if (file != null) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path,
            filename: file.path.split('/').last));
      }

      request.headers.addAll({
        'Accept': 'application/json',
        'User-Agent': 'Bookey-Flutter-App/1.0',
      });

      final streamedResponse = await request.send().timeout(Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to start audio processing');
      }
    } catch (e) {
      throw Exception('Failed to start audio processing: ${e.toString()}');
    }
  }

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
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getResults(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/results/$sessionId'),
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
      return null;
    }
  }
}