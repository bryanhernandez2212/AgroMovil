import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agromarket/controllers/auth_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureText = true;
  bool _obscureRepeatText = true;
  String _selectedRole = 'comprador';
  final List<String> _availableRoles = ['comprador', 'vendedor'];

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    
    // Validaciones básicas
    if (_nombreController.text.isEmpty) {
      _showErrorSnackBar('Por favor, ingresa tu nombre completo');
      return;
    }
    
    if (_emailController.text.isEmpty) {
      _showErrorSnackBar('Por favor, ingresa tu correo electrónico');
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar('Por favor, ingresa una contraseña segura');
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('Las contraseñas no coinciden. Verifica e inténtalo de nuevo');
      return;
    }
    
    if (_passwordController.text.length < 6) {
      _showErrorSnackBar('La contraseña debe tener al menos 6 caracteres');
      return;
    }


    final success = await authController.register(
      _nombreController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      _selectedRole,
    );

    if (success && mounted) {
      _showSuccessSnackBar('¡Cuenta creada exitosamente! Ya puedes iniciar sesión');
    } else if (mounted) {
      _showErrorSnackBar(authController.errorMessage ?? 'Error al crear la cuenta. Inténtalo de nuevo');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        duration: const Duration(seconds: 4),
        animation: CurvedAnimation(
          parent: kAlwaysCompleteAnimation,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF115213),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        duration: const Duration(seconds: 3),
        animation: CurvedAnimation(
          parent: kAlwaysCompleteAnimation,
          curve: Curves.easeOut,
        ),
        action: SnackBarAction(
          label: 'Iniciar Sesión',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Fondo de hojas solo en la parte superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.50,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/fondo.JPG'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Curva blanca decorativa
          Positioned(
            top: MediaQuery.of(context).size.height * 0.60,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 100),
              painter: SmoothWavePainter(),
            ),
          ),

          // Botón de regreso
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFDDF2DD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Color.fromARGB(255, 0, 0, 0),
                  size: 20,
                ),
              ),
            ),
          ),

          // Área blanca con contenido
          Positioned(
            top: MediaQuery.of(context).size.height * 0.30,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1B5E20),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Crear cuenta',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B5E20),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 35,
                          height: 25,
                          child: const Icon(
                            Icons.eco,
                            color: Color(0xFF2E7D32),
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Regístrate para comenzar',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Campo de nombre
                    _buildInputField(
                      controller: _nombreController,
                      hintText: 'Nombre completo',
                      icon: Icons.person,
                      keyboardType: TextInputType.text,
                    ),

                    const SizedBox(height: 20),
                    
                    // Campo de email
                    _buildInputField(
                      controller: _emailController,
                      hintText: 'Correo electrónico',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Campo de contraseña
                    _buildPasswordField(
                      controller: _passwordController,
                      hintText: 'Contraseña',
                      icon: Icons.lock,
                      obscureText: _obscureText,
                      onToggle: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Campo de confirmar contraseña
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirmar contraseña',
                      icon: Icons.lock_outline,
                      obscureText: _obscureRepeatText,
                      onToggle: () {
                        setState(() {
                          _obscureRepeatText = !_obscureRepeatText;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Campo de selección de rol
                    _buildRoleSelector(),
                    
                    const SizedBox(height: 30),
                    
                    // Botón de registro
                    Consumer<AuthController>(
                      builder: (context, authController, child) {
                        return GestureDetector(
                          onTap: authController.isLoading ? null : _register,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: authController.isLoading
                                  ? Colors.grey
                                  : const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: authController.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Registrarse',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Enlace de login
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            children: [
                              TextSpan(text: "¿Ya tienes cuenta? "),
                              TextSpan(
                                text: 'Iniciar sesión',
                                style: TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[600],
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedRole,
        decoration: InputDecoration(
          hintText: 'Selecciona tu rol',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.person_outline, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        items: _availableRoles.map((String role) {
          return DropdownMenuItem<String>(
            value: role,
            child: Text(
              _getRoleDisplayName(role),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF333333),
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedRole = newValue;
            });
          }
        },
        dropdownColor: Colors.white,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'comprador':
        return 'Comprador';
      case 'vendedor':
        return 'Vendedor';
      default:
        return role;
    }
  }

}

class SmoothWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    
    // Crear una curva suave
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.4,
      size.width * 0.5, size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.8,
      size.width, size.height * 0.5,
    );
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}