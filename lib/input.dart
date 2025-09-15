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

    // FIXED: Use the actual API values, not abbreviated ones
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

  // REPLACE THESE METHODS:
  String _getSafeGenreValue() {
    return _genres.any((genre) => genre['value'] == _selectedGenre)
        ? _selectedGenre
        : 'Fantasy'; // Use actual API value
  }

  String _getSafeDurationValue() {
    return _durations.any((duration) => duration['value'] == _selectedDuration)
        ? _selectedDuration
        : 'Medium (10-20 minutes read)'; // Use actual API value
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
    });

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
        widget.onStoryGenerated(result);
        _showSnackBar('Story generated successfully', isError: false);
        _clearForm();
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
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
              _buildFormLayout(),
              const SizedBox(height: 20),
              _buildGenerateSection(),
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'AI Story Generator',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D2D),
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (_wordCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B7355).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8B7355).withOpacity(0.2),
              ),
            ),
            child: Text(
              '$_wordCount words',
              style: const TextStyle(
                color: Color(0xFF8B7355),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFormLayout() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: 'Story Title',
                    hint: 'Enter a compelling title...',
                    isRequired: true,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _subjectController,
                    label: 'Plot & Theme',
                    hint: 'Describe the main storyline and central themes...',
                    isRequired: true,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildDropdownField(
                    label: 'Genre',
                    value: _getSafeGenreValue(),
                    items: _genres,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedGenre = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    label: 'Length',
                    value: _getSafeDurationValue(),
                    items: _durations,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedDuration = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _charactersController,
                label: 'Characters',
                hint: 'Describe main characters (optional)...',
                isRequired: false,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _contextController,
                label: 'Setting',
                hint: 'Time period, location, context (optional)...',
                isRequired: false,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isRequired,
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.05,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 3),
              const Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              color: Color(0xFF2D2D2D),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFE8E3DD),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFE8E3DD),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF2D2D2D),
                  width: 1.5,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: maxLines > 1 ? 14 : 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF2D2D2D),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            dropdownColor: Colors.white,
            elevation: 6,
            isExpanded: true, // This prevents text cutoff
            style: const TextStyle(
              color: Color(0xFF2D2D2D),
              fontSize: 13, // Slightly smaller to fit better
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFE8E3DD),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFE8E3DD),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF2D2D2D),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, // Slightly less padding
                vertical: 12,
              ),
            ),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item['value'],
                child: Text(
                  item['label']!,
                  style: const TextStyle(
                    color: Color(0xFF2D2D2D),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList(),
            onChanged: onChanged,
            icon: const Icon(
              Icons.expand_more,
              color: Color(0xFF8B7355),
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateSection() {
    return Row(
      children: [
        if (!_isGenerating)
          Expanded(
            child: TextButton(
              onPressed: _clearForm,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B7355),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Clear Form',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (!_isGenerating) const SizedBox(width: 12),
        Expanded(
          flex: _isGenerating ? 1 : 2,
          child: Container(
            height: 44,
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
              onPressed: _isGenerating ? null : _generateStory,
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
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Generating...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Generate Story',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
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

  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    _breathingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathingController.dispose();
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

        _showSnackBar('Audio file selected successfully', isError: false);
      }
    } catch (e) {
      _showSnackBar('Selection failed: $e', isError: true);
    }
  }

  Future<void> _processAudio() async {
    if (_selectedAudioFile == null && _selectedWebAudioFile == null) {
      _showSnackBar('Please select an audio file', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final isHealthy = await ApiService.checkMediaApiHealth();
      if (!isHealthy) {
        throw Exception('Audio service temporarily unavailable');
      }

      final result = await ApiService.processAudio(
        _selectedAudioFile,
        _selectedWebAudioFile,
        maxConcurrent: 3,
      );

      if (result?.success == true) {
        widget.onAudioProcessed(result!);
        _showSnackBar('Audio processed successfully', isError: false);
        setState(() {
          _selectedAudioFile = null;
          _selectedWebAudioFile = null;
        });
      } else {
        throw Exception(result?.message ?? 'Processing failed');
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('timeout')) {
        errorMessage =
            'Processing timeout - please try again with a smaller file';
      } else if (errorMessage.contains('Connection')) {
        errorMessage = 'Connection error - check your network';
      }
      _showSnackBar(errorMessage, isError: true);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
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
    final hasFile = _selectedAudioFile != null || _selectedWebAudioFile != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3F0), // Beige background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8E3DD),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildAudioIcon(),
            const SizedBox(height: 20),
            _buildTitle(),
            const SizedBox(height: 8),
            _buildDescription(),
            const SizedBox(height: 24),
            if (!hasFile) _buildUploadArea(),
            if (hasFile) ...[
              _buildSelectedFile(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioIcon() {
    final hasFile = _selectedAudioFile != null || _selectedWebAudioFile != null;

    return AnimatedBuilder(
      animation: _breathingAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: hasFile ? 1.0 : _breathingAnimation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: hasFile
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFF2D2D2D), const Color(0xFF3D3D3D)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (hasFile
                          ? const Color(0xFF10B981)
                          : const Color(0xFF2D2D2D))
                      .withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              hasFile ? Icons.check_circle_outline : Icons.audiotrack,
              color: Colors.white,
              size: 32,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    final hasFile = _selectedAudioFile != null || _selectedWebAudioFile != null;

    return Text(
      hasFile ? 'Audio Ready' : 'Audio Processing',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2D2D2D),
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildDescription() {
    final hasFile = _selectedAudioFile != null || _selectedWebAudioFile != null;

    return Text(
      hasFile
          ? 'Your audio file is ready for speech-to-text conversion'
          : 'Upload audio files for AI-powered transcription',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF8B7355),
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _pickAudioFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFE8E3DD),
            width: 1.5,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF8B7355).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: Color(0xFF8B7355),
                size: 22,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Drop audio file here or click to browse',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Supports MP3, WAV, M4A, AAC, FLAC formats',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8B7355),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
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
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.audiotrack,
              color: Color(0xFF059669),
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
                  'Ready for transcription',
                  style: TextStyle(
                    color: Color(0xFF059669),
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () {
              setState(() {
                _selectedAudioFile = null;
                _selectedWebAudioFile = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B7355),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Remove File',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            height: 44,
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
              onPressed: _isProcessing ? null : _processAudio,
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
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.transform, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Process Audio',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
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

class _EnhancedCameraWidgetState extends State<EnhancedCameraWidget>
    with TickerProviderStateMixin {
  List<File> _selectedImages = [];
  List<PlatformFile> _selectedWebImages = [];
  bool _isProcessing = false;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

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

        final count = result.files.length;
        _showSnackBar(
          '${count} image${count > 1 ? 's' : ''} selected successfully',
          isError: false,
        );
      }
    } catch (e) {
      _showSnackBar('Selection failed: $e', isError: true);
    }
  }

  Future<void> _processImages() async {
    if (_selectedImages.isEmpty && _selectedWebImages.isEmpty) {
      _showSnackBar('Please select images first', isError: true);
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

      if (result?.success == true) {
        widget.onImagesProcessed(result!);
        _showSnackBar('Images processed successfully', isError: false);
        setState(() {
          _selectedImages.clear();
          _selectedWebImages.clear();
        });
      } else {
        throw Exception(result?.message ?? 'Processing failed');
      }
    } catch (e) {
      _showSnackBar('Processing failed: ${e.toString()}', isError: true);
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
    final hasImages =
        _selectedImages.isNotEmpty || _selectedWebImages.isNotEmpty;
    final imageCount =
        kIsWeb ? _selectedWebImages.length : _selectedImages.length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3F0), // Beige background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8E3DD),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildCameraIcon(),
            const SizedBox(height: 20),
            _buildTitle(),
            const SizedBox(height: 8),
            _buildDescription(),
            const SizedBox(height: 24),
            if (!hasImages) _buildUploadArea(),
            if (hasImages) ...[
              _buildImageGrid(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraIcon() {
    final hasImages =
        _selectedImages.isNotEmpty || _selectedWebImages.isNotEmpty;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasImages
              ? [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)]
              : [const Color(0xFF2D2D2D), const Color(0xFF3D3D3D)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (hasImages ? const Color(0xFF8B5CF6) : const Color(0xFF2D2D2D))
                    .withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          ? '$imageCount Image${imageCount > 1 ? 's' : ''} Selected'
          : 'Image Recognition',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF2D2D2D),
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildDescription() {
    final hasImages =
        _selectedImages.isNotEmpty || _selectedWebImages.isNotEmpty;

    return Text(
      hasImages
          ? 'Your images are ready for AI-powered text extraction'
          : 'Upload images for advanced OCR and text recognition',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF8B7355),
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _pickImages,
      child: AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFE8E3DD),
                width: 1.5,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B7355).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Color(0xFF8B7355),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Drop images here or click to select',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Supports JPG, PNG, HEIC, WebP formats • Multiple files allowed',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B7355),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageGrid() {
    final imageCount =
        kIsWeb ? _selectedWebImages.length : _selectedImages.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF7C3AED),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$imageCount Selected Image${imageCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Color(0xFF2D2D2D),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Text(
                      'Ready for OCR processing',
                      style: TextStyle(
                        color: Color(0xFF7C3AED),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageCount,
              itemBuilder: (context, index) {
                final fileName = kIsWeb
                    ? _selectedWebImages[index].name
                    : _selectedImages[index].path.split('/').last;

                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 100,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image,
                              color: Color(0xFF8B5CF6),
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              fileName,
                              style: const TextStyle(
                                color: Color(0xFF2D2D2D),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () {
              setState(() {
                _selectedImages.clear();
                _selectedWebImages.clear();
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8B7355),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            height: 44,
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
              onPressed: _isProcessing ? null : _processImages,
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
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Extract Text',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
