import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

// Story Generator Widget
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

  List<Map<String, String>> _genres = [
    {'value': 'Action/Adventure', 'label': 'Action/Adventure'},
    {'value': 'Comedy', 'label': 'Comedy'},
    {'value': 'Drama', 'label': 'Drama'}, // Not 'DRAMA'
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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();

    _subjectController.addListener(_updateWordCount);
    _charactersController.addListener(_updateWordCount);
    _contextController.addListener(_updateWordCount);

    // Initialize with safe default values that exist in the lists
    _selectedGenre = _genres.isNotEmpty ? _genres.first['value']! : 'Fantasy';
    _selectedDuration = _durations.isNotEmpty
        ? _durations.first['value']!
        : 'Medium (10-20 minutes read)';

    // Load from API after initialization
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
        : (_genres.isNotEmpty ? _genres.first['value']! : 'Fantasy');
  }

  String _getSafeDurationValue() {
    return _durations.any((duration) => duration['value'] == _selectedDuration)
        ? _selectedDuration
        : (_durations.isNotEmpty
            ? _durations.first['value']!
            : 'Medium (10-20 minutes read)');
  }

  Future<void> _loadGenresAndDurations() async {
    try {
      print('Loading genres and durations from API...');

      // Load genres from API
      final genres = await ApiService.getAvailableGenres();
      print('Received genres from API: $genres');

      if (genres.isNotEmpty) {
        setState(() {
          _genres = genres;
          // Ensure selected genre exists in the new list
          if (!_genres.any((g) => g['value'] == _selectedGenre)) {
            _selectedGenre = _genres.first['value']!;
            print('Updated selected genre to: $_selectedGenre');
          }
        });
      }

      // Load durations from API
      final durations = await ApiService.getAvailableDurations();
      print('Received durations from API: $durations');

      if (durations.isNotEmpty) {
        setState(() {
          _durations = durations;
          // Ensure selected duration exists in the new list
          if (!_durations.any((d) => d['value'] == _selectedDuration)) {
            _selectedDuration = _durations.first['value']!;
            print('Updated selected duration to: $_selectedDuration');
          }
        });
      }
    } catch (e) {
      print('Failed to load genres/durations from API: $e');
      // Keep default values if API fails
    }
  }

  Future<void> _generateStory() async {
    if (!_canGenerateStory()) {
      _showErrorSnackBar('Please fill in the title and subject fields');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      print('Creating story request with:');
      print('Title: ${_titleController.text.trim()}');
      print('Subject: ${_subjectController.text.trim()}');
      print('Genre: $_selectedGenre');
      print('Duration: $_selectedDuration');

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

      print('Making API call to generate story...');
      final result = await ApiService.generateStory(storyRequest);

      if (result.success) {
        print('Story generated successfully: ${result.totalWords} words');
        widget.onStoryGenerated(result);
        _showSuccessSnackBar(
            'Story generated successfully! Check Processing tab');
        // Clear form after successful generation
        _clearForm();
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      print('Story generation error: $e');
      _showErrorSnackBar('Failed to generate story: ${e.toString()}');
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A23),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6366F1).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFormFields(),
            const SizedBox(height: 24),
            _buildGenreDurationSelectors(),
            const SizedBox(height: 24),
            _buildGenerateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'AI Story Generator',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (_wordCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_wordCount input words',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _titleController,
          label: 'Story Title*',
          hint: 'Enter an engaging title for your story...',
          icon: Icons.title,
          maxLines: 1,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _subjectController,
          label: 'Subject/Plot*',
          hint: 'Describe the main plot or theme of your story...',
          icon: Icons.subject,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _charactersController,
          label: 'Characters (Optional)',
          hint: 'Describe the main characters...',
          icon: Icons.people,
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _contextController,
          label: 'Setting/Context (Optional)',
          hint: 'Describe the setting, time period, or background...',
          icon: Icons.place,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            filled: true,
            fillColor: const Color(0xFF2A2A3A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreDurationSelectors() {
    return Column(
      children: [
        _buildGenreSelector(),
        const SizedBox(height: 16),
        _buildDurationSelector(),
      ],
    );
  }

  Widget _buildGenreSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Genre',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _getSafeGenreValue(),
            dropdownColor: const Color(0xFF2A2A3A),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon:
                  Icon(Icons.category, color: Color(0xFF6366F1), size: 20),
            ),
            items: _genres.map((genre) {
              return DropdownMenuItem<String>(
                value: genre['value'],
                child: Text(
                  genre['label']!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedGenre = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Length',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _getSafeDurationValue(),
            dropdownColor: const Color(0xFF2A2A3A),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon:
                  Icon(Icons.schedule, color: Color(0xFF6366F1), size: 20),
            ),
            items: _durations.map((duration) {
              return DropdownMenuItem<String>(
                value: duration['value'],
                child: Text(
                  duration['label']!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedDuration = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateStory,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isGenerating
                ? LinearGradient(
                    colors: [Colors.grey.shade600, Colors.grey.shade700])
                : const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: _isGenerating
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Generating Story...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Generate Story',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// Audio Upload Widget
class AudioUploadWidget extends StatefulWidget {
  final Function(ProcessingResult) onAudioProcessed;

  const AudioUploadWidget({super.key, required this.onAudioProcessed});

  @override
  State<AudioUploadWidget> createState() => _AudioUploadWidgetState();
}

class _AudioUploadWidgetState extends State<AudioUploadWidget>
    with TickerProviderStateMixin {
  File? _selectedAudioFile;
  PlatformFile? _selectedWebAudioFile;
  bool _isProcessing = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _selectedWebAudioFile = result.files.single;
            _selectedAudioFile = null;
          } else {
            _selectedAudioFile = File(result.files.single.path!);
            _selectedWebAudioFile = null;
          }
        });

        _showSuccessSnackBar('Audio file selected successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting audio file: $e');
    }
  }

  Future<void> _processAudio() async {
    if (_selectedAudioFile == null && _selectedWebAudioFile == null) {
      _showErrorSnackBar('Please select an audio file first');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Check API health first
      final isHealthy = await ApiService.checkMediaApiHealth();
      if (!isHealthy) {
        throw Exception(
            'Audio processing service is currently unavailable. Please try again later.');
      }

      final result = await ApiService.processAudio(
        _selectedAudioFile,
        _selectedWebAudioFile,
        maxConcurrent: 3,
      );

      if (result != null && result.success) {
        widget.onAudioProcessed(result);
        _showSuccessSnackBar(
            'Audio processed successfully! Check Processing tab');
        // Clear the selected file after successful processing
        setState(() {
          _selectedAudioFile = null;
          _selectedWebAudioFile = null;
        });
      } else {
        throw Exception(result?.message ?? 'Unknown error occurred');
      }
    } catch (e) {
      String errorMessage = e.toString();

      // Provide user-friendly error messages
      if (errorMessage.contains('timeout')) {
        errorMessage =
            'Audio processing timeout. Large files may take several minutes. Please try again.';
      } else if (errorMessage.contains('Connection reset') ||
          errorMessage.contains('Connection refused') ||
          errorMessage.contains('Failed to fetch')) {
        errorMessage =
            'Unable to connect to audio processing server. Check your internet connection.';
      } else if (errorMessage.contains('File size too large')) {
        errorMessage =
            'Audio file is too large. Please use a file smaller than 50MB.';
      } else if (errorMessage.contains('Invalid audio format')) {
        errorMessage =
            'Unsupported audio format. Please use MP3, WAV, M4A, AAC, FLAC, or OGG files.';
      } else if (errorMessage.contains('service is currently unavailable')) {
        errorMessage =
            'Audio processing service is temporarily unavailable. Please try again later.';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_selectedAudioFile != null || _selectedWebAudioFile != null)
              ? const Color(0xFF10B981).withOpacity(0.5)
              : const Color(0xFF6366F1).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildAudioIcon(),
          const SizedBox(height: 16),
          _buildTitle(),
          const SizedBox(height: 8),
          _buildSubtitle(),
          const SizedBox(height: 20),
          _buildUploadButton(),
          if (_selectedAudioFile != null || _selectedWebAudioFile != null) ...[
            const SizedBox(height: 16),
            _buildSelectedFile(),
            const SizedBox(height: 16),
            _buildProcessButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: (_selectedAudioFile != null || _selectedWebAudioFile != null)
              ? 1.0
              : _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: (_selectedAudioFile != null ||
                        _selectedWebAudioFile != null)
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (_selectedAudioFile != null ||
                          _selectedWebAudioFile != null)
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              (_selectedAudioFile != null || _selectedWebAudioFile != null)
                  ? Icons.check_circle
                  : Icons.audiotrack,
              color: Colors.white,
              size: 32,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return Text(
      (_selectedAudioFile != null || _selectedWebAudioFile != null)
          ? 'Audio File Selected!'
          : 'Upload Audio Book',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      (_selectedAudioFile != null || _selectedWebAudioFile != null)
          ? 'Ready to extract text using AI speech recognition'
          : 'Upload MP3, WAV, or other audio formats for speech-to-text conversion',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 14,
      ),
    );
  }

  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _pickAudioFile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  (_selectedAudioFile != null || _selectedWebAudioFile != null)
                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                      : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  (_selectedAudioFile != null || _selectedWebAudioFile != null)
                      ? Icons.swap_horiz
                      : Icons.upload_file,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  (_selectedAudioFile != null || _selectedWebAudioFile != null)
                      ? 'Change Audio File'
                      : 'Choose Audio File',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFile() {
    final fileName = kIsWeb
        ? (_selectedWebAudioFile?.name ?? 'Audio File')
        : (_selectedAudioFile?.path.split('/').last ?? 'Audio File');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.audiotrack,
                color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Speech-to-text conversion ready',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedAudioFile = null;
                _selectedWebAudioFile = null;
              });
            },
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processAudio,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isProcessing
                ? LinearGradient(
                    colors: [Colors.grey.shade600, Colors.grey.shade700])
                : const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFEF4444)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Processing Audio...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.transform, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Process Audio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// Enhanced Image/Camera Widget
class EnhancedCameraWidget extends StatefulWidget {
  final Function(ProcessingResult) onImagesProcessed;

  const EnhancedCameraWidget({super.key, required this.onImagesProcessed});

  @override
  State<EnhancedCameraWidget> createState() => _EnhancedCameraWidgetState();
}

class _EnhancedCameraWidgetState extends State<EnhancedCameraWidget> {
  List<File> _selectedImages = [];
  List<PlatformFile> _selectedWebImages = [];
  bool _isProcessing = false;

  Future<void> _pickImages() async {
    try {
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
            _selectedImages =
                result.files.map((file) => File(file.path!)).toList();
            _selectedWebImages = [];
          }
        });

        _showSuccessSnackBar(
            '${result.files.length} images selected successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting images: $e');
    }
  }

  Future<void> _processImages() async {
    if (_selectedImages.isEmpty && _selectedWebImages.isEmpty) {
      _showErrorSnackBar('Please select images first');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      ProcessingResult? result;

      if (kIsWeb) {
        result = await ApiService.processImagesWeb(_selectedWebImages);
      } else {
        result = await ApiService.processImages(_selectedImages);
      }

      // Add null check
      if (result == null) {
        throw Exception('Received null result from API');
      }

      if (result.success) {
        widget.onImagesProcessed(result);
        _showSuccessSnackBar(
            'Images processed successfully! Check Processing tab');
        // Clear the selected images after successful processing
        setState(() {
          _selectedImages.clear();
          _selectedWebImages.clear();
        });
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      print('Processing error details: $e');
      _showErrorSnackBar('Failed to process images: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      if (kIsWeb) {
        _selectedWebImages.removeAt(index);
      } else {
        _selectedImages.removeAt(index);
      }
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImages =
        _selectedImages.isNotEmpty || _selectedWebImages.isNotEmpty;
    final imageCount =
        kIsWeb ? _selectedWebImages.length : _selectedImages.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasImages
              ? const Color(0xFF8B5CF6).withOpacity(0.5)
              : const Color(0xFF6366F1).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildCameraIcon(),
          const SizedBox(height: 16),
          _buildTitle(),
          const SizedBox(height: 8),
          _buildSubtitle(),
          const SizedBox(height: 20),
          _buildSelectButton(),
          if (hasImages) ...[
            const SizedBox(height: 16),
            _buildImagesList(),
            const SizedBox(height: 16),
            _buildProcessButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraIcon() {
    final hasImages =
        _selectedImages.isNotEmpty || _selectedWebImages.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasImages
              ? [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)]
              : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: hasImages
                ? const Color(0xFF8B5CF6).withOpacity(0.3)
                : const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        hasImages ? Icons.photo_library : Icons.camera_alt,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _buildTitle() {
    final hasImages =
        _selectedImages.isNotEmpty || _selectedWebImages.isNotEmpty;
    final imageCount =
        kIsWeb ? _selectedWebImages.length : _selectedImages.length;

    return Text(
      hasImages
          ? '$imageCount Image${imageCount > 1 ? 's' : ''} Selected!'
          : 'Upload Images for OCR',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSubtitle() {
    final hasImages =
        _selectedImages.isNotEmpty || _selectedWebImages.isNotEmpty;

    return Text(
      hasImages
          ? 'Ready to extract text using AI-powered OCR technology'
          : 'Upload photos of documents, books, or handwritten text for AI text extraction',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: 14,
      ),
    );
  }

  Widget _buildSelectButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _pickImages,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Select Images',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagesList() {
    final imageCount =
        kIsWeb ? _selectedWebImages.length : _selectedImages.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.photo_library,
                    color: Color(0xFF8B5CF6), size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                '$imageCount Selected Image${imageCount > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageCount,
              itemBuilder: (context, index) {
                final fileName = kIsWeb
                    ? _selectedWebImages[index].name
                    : _selectedImages[index].path.split('/').last;

                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 120,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A3A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image,
                                color: Color(0xFF8B5CF6), size: 24),
                            const SizedBox(height: 4),
                            Text(
                              fileName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processImages,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isProcessing
                ? LinearGradient(
                    colors: [Colors.grey.shade600, Colors.grey.shade700])
                : const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFEF4444)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: _isProcessing
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Processing Images...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.document_scanner,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Extract Text with OCR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
