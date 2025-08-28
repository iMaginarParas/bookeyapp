import 'package:flutter/material.dart';
import 'video_service.dart';
import 'network_debug.dart';

class ApiTestWidget extends StatefulWidget {
  const ApiTestWidget({super.key});

  @override
  State<ApiTestWidget> createState() => _ApiTestWidgetState();
}

class _ApiTestWidgetState extends State<ApiTestWidget> {
  Map<String, dynamic>? testResults;
  Map<String, dynamic>? diagnosticResults;
  bool isLoading = false;
  bool isRunningDiagnostics = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('API Test & Diagnostics'),
        backgroundColor: const Color(0xFF1A1A23),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Quick Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _testApi,
                    icon: isLoading 
                        ? const SizedBox(
                            width: 16, 
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.api),
                    label: const Text('Test API'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isRunningDiagnostics ? null : _runDiagnostics,
                    icon: isRunningDiagnostics 
                        ? const SizedBox(
                            width: 16, 
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.troubleshoot),
                    label: const Text('Full Diagnostics'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Quick connectivity indicator
            FutureBuilder<bool>(
              future: NetworkDebugUtil.quickConnectivityTest(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16, 
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Testing connectivity...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                }
                
                final isConnected = snapshot.data ?? false;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isConnected 
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.error,
                        color: isConnected ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isConnected 
                            ? 'API Server is reachable ✅'
                            : 'API Server unreachable ❌',
                        style: TextStyle(
                          color: isConnected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Results display
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // API Test Results
                    if (testResults != null) ...[
                      _buildApiTestResults(),
                      const SizedBox(height: 20),
                    ],
                    
                    // Diagnostic Results
                    if (diagnosticResults != null) ...[
                      _buildDiagnosticResults(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiTestResults() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.api, color: Color(0xFF6366F1), size: 20),
              SizedBox(width: 8),
              Text(
                'API Test Results',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...testResults!.entries.map((entry) {
            final endpoint = entry.key;
            final result = entry.value as Map<String, dynamic>;
            final status = result['status'];
            final method = result['method'];
            final available = result['available'] as bool;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: available 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: available ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getMethodColor(method),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          method,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          endpoint,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: available ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (result['body'] != null) ...[
                    const Text(
                      'Response:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        result['body'],
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  if (result['error'] != null) ...[
                    const Text(
                      'Error:',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result['error'],
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDiagnosticResults() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.troubleshoot, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Text(
                'Network Diagnostics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Platform Info
          _buildDiagnosticSection(
            'Platform Info',
            diagnosticResults!['platform'] as Map<String, dynamic>,
            Colors.blue,
          ),
          
          // Connectivity
          _buildDiagnosticSection(
            'Connectivity',
            diagnosticResults!['connectivity'] as Map<String, dynamic>,
            Colors.green,
          ),
          
          // DNS Resolution
          _buildDnsSection(),
          
          // SSL Check
          _buildSslSection(),
          
          // API Endpoints
          _buildApiEndpointsSection(),
        ],
      ),
    );
  }

  Widget _buildDiagnosticSection(String title, Map<String, dynamic> data, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...data.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(
                  '${entry.key}: ',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDnsSection() {
    final dnsData = diagnosticResults!['dns_resolution'] as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DNS Resolution',
            style: TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...dnsData.entries.map((entry) {
            final hostname = entry.key;
            final data = entry.value as Map<String, dynamic>;
            final resolved = data['resolved'] as bool;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    resolved ? Icons.check_circle : Icons.error,
                    color: resolved ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hostname,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSslSection() {
    final sslData = diagnosticResults!['ssl_check'] as Map<String, dynamic>;
    final sslWorking = sslData['ssl_working'] as bool;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (sslWorking ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (sslWorking ? Colors.green : Colors.red).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sslWorking ? Icons.lock : Icons.lock_open,
                color: sslWorking ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'SSL/TLS Connection',
                style: TextStyle(
                  color: sslWorking ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sslWorking ? 'SSL connection successful' : 'SSL connection failed',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          if (!sslWorking && sslData['error'] != null)
            Text(
              'Error: ${sslData['error']}',
              style: const TextStyle(color: Colors.red, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildApiEndpointsSection() {
    final apiData = diagnosticResults!['api_endpoints'] as Map<String, dynamic>;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API Endpoints (Detailed)',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...apiData.entries.map((entry) {
            final endpoint = entry.key;
            final data = entry.value as Map<String, dynamic>;
            final success = data['success'] as bool;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (success ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getMethodColor(data['method']),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          data['method'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          endpoint,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      Icon(
                        success ? Icons.check_circle : Icons.error,
                        color: success ? Colors.green : Colors.red,
                        size: 14,
                      ),
                    ],
                  ),
                  if (!success && data['likely_cause'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Cause: ${data['likely_cause']}',
                      style: const TextStyle(color: Colors.red, fontSize: 10),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'GET':
        return Colors.blue;
      case 'POST':
        return Colors.green;
      case 'PUT':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _testApi() async {
    setState(() {
      isLoading = true;
    });

    try {
      final results = await VideoGenerationService.testApiEndpoints();
      setState(() {
        testResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing API: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _runDiagnostics() async {
    setState(() {
      isRunningDiagnostics = true;
    });

    try {
      final results = await NetworkDebugUtil.runDiagnostics();
      setState(() {
        diagnosticResults = results;
      });
      
      // Also print to console for debugging
      NetworkDebugUtil.printDiagnosticResults(results);
      
      // Show summary in snackbar
      final connectivity = results['connectivity'] as Map<String, dynamic>;
      final internetAccess = connectivity['internet_access'] as bool;
      final sslCheck = results['ssl_check'] as Map<String, dynamic>;
      final sslWorking = sslCheck['ssl_working'] as bool;
      
      String message;
      Color backgroundColor;
      
      if (internetAccess && sslWorking) {
        message = '✅ Network diagnostics completed - All systems operational';
        backgroundColor = Colors.green;
      } else if (internetAccess && !sslWorking) {
        message = '⚠️ Internet OK but SSL/API issues detected';
        backgroundColor = Colors.orange;
      } else {
        message = '❌ Network connectivity issues detected';
        backgroundColor = Colors.red;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 4),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error running diagnostics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isRunningDiagnostics = false;
      });
    }
  }
}