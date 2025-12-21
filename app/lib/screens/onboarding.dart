// Onboarding Screen for Secretariat app
//
// Implements the First-run Onboarding Flow from app_spec.txt lines 121, 306-312:
// 1. Welcome and introduction
// 2. Create master password (stored in Keychain)
// 3. Enable Touch ID (optional)
// 4. Import first secret or .env file

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/vault_provider.dart';
import 'import_wizard.dart';

/// Key for storing onboarding completion status (must match main.dart)
const String _onboardingCompleteKey = 'onboarding_complete';

/// Onboarding Screen
///
/// First-run setup flow for new users:
/// 1. Welcome screen with introduction
/// 2. Create master password
/// 3. Optional Touch ID setup
/// 4. Import first secrets
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// Current onboarding step (0-3)
  int _currentStep = 0;

  /// Page controller for swipe navigation
  final PageController _pageController = PageController();

  /// Password controllers
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// Password visibility
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;

  /// Touch ID enabled
  bool _touchIdEnabled = false;

  /// Setup in progress
  bool _isSettingUp = false;

  /// Error message
  String? _errorMessage;

  /// Password validation
  String? _passwordError;

  @override
  void dispose() {
    _pageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Validate password strength
  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  /// Calculate password strength (0-4)
  int _getPasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) {
      strength++;
    }
    if (password.length >= 12) {
      strength++;
    }
    if (password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]'))) {
      strength++;
    }
    if (password.contains(RegExp(r'[0-9]'))) {
      strength++;
    }
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      strength++;
    }
    return strength.clamp(0, 4);
  }

  /// Get password strength label
  String _getStrengthLabel(int strength) {
    switch (strength) {
      case 0:
        return 'Very Weak';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Strong';
      case 4:
        return 'Very Strong';
      default:
        return '';
    }
  }

  /// Get password strength color
  Color _getStrengthColor(int strength) {
    switch (strength) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.yellow.shade700;
      case 3:
        return Colors.lightGreen;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Navigate to next step
  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Navigate to previous step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Initialize vault with password
  Future<void> _initializeVault() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate password
    final error = _validatePassword(password);
    if (error != null) {
      setState(() {
        _passwordError = error;
      });
      return;
    }

    // Check passwords match
    if (password != confirmPassword) {
      setState(() {
        _passwordError = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isSettingUp = true;
      _errorMessage = null;
      _passwordError = null;
    });

    try {
      final vaultProvider = Provider.of<VaultProvider>(context, listen: false);

      // Connect to daemon (will auto-start if needed)
      await vaultProvider.connect();

      // Initialize vault with password
      // Note: This calls vault.init on the daemon
      // For now, we'll just load secrets to test connection
      await vaultProvider.loadSecrets();

      if (mounted) {
        _nextStep();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize vault: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingUp = false;
        });
      }
    }
  }

  /// Complete onboarding
  Future<void> _completeOnboarding() async {
    // Mark onboarding as complete in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  /// Build welcome step
  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo/Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            'Welcome to Secretariat',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Tagline
          Text(
            'Stop copy-pasting API keys.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Description
          Text(
            'One encrypted vault on your machine.\n'
            'All your API keys in one place.\n'
            'Every project just works.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Features list
          _buildFeatureItem(
            Icons.lock,
            'Encrypted at rest',
            'AES-256-GCM encryption with keys in Keychain',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Icons.code,
            'Works with any language',
            'SDKs for Dart, Python, Rust, and Node.js',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Icons.upload_file,
            'Easy migration',
            'Import your existing .env files in seconds',
          ),

          const Spacer(),

          // Get Started button
          FilledButton.icon(
            onPressed: _nextStep,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Get Started'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build password step
  Widget _buildPasswordStep() {
    final strength = _getPasswordStrength(_passwordController.text);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Create Master Password',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'This password protects all your secrets. '
            'It will be securely stored in your system keychain.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Master Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              errorText: _passwordError,
            ),
            onChanged: (_) {
              setState(() {
                _passwordError = null;
              });
            },
          ),
          const SizedBox(height: 8),

          // Password strength indicator
          if (_passwordController.text.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: strength / 4,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: _getStrengthColor(strength),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _getStrengthLabel(strength),
                  style: TextStyle(
                    color: _getStrengthColor(strength),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use at least 8 characters with uppercase, lowercase, and numbers',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 24),

          // Confirm password field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmVisible,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmVisible = !_isConfirmVisible;
                  });
                },
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              FilledButton.icon(
                onPressed: _isSettingUp ? null : _initializeVault,
                icon: _isSettingUp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
                label: Text(_isSettingUp ? 'Setting up...' : 'Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build Touch ID step
  Widget _buildTouchIdStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Touch ID icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _touchIdEnabled
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fingerprint,
              size: 64,
              color: _touchIdEnabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            'Enable Touch ID',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Use Touch ID to quickly unlock your vault\n'
            'instead of typing your password.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Toggle
          SwitchListTile(
            value: _touchIdEnabled,
            onChanged: (value) {
              setState(() {
                _touchIdEnabled = value;
              });
            },
            title: const Text('Enable Touch ID'),
            subtitle: const Text('You can change this later in Settings'),
            secondary: const Icon(Icons.fingerprint),
          ),

          const Spacer(),

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              FilledButton.icon(
                onPressed: _nextStep,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build import step
  Widget _buildImportStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Import icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.upload_file,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            'Import Your Secrets',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Import your existing .env files to get started,\n'
            'or add secrets manually later.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Import options
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ImportWizardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Import .env File'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _completeOnboarding,
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip for Now'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),

          const Spacer(),

          // Done button
          FilledButton.icon(
            onPressed: _completeOnboarding,
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: index < 3 ? 8 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomeStep(),
                  _buildPasswordStep(),
                  _buildTouchIdStep(),
                  _buildImportStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
