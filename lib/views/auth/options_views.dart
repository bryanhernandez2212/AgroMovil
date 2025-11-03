import 'package:agromarket/estructure/product_estructure.dart';
import 'package:agromarket/services/user_role_service.dart';
import 'package:flutter/material.dart';

class OptionPage extends StatefulWidget {
  const OptionPage({super.key});

  @override
  State<OptionPage> createState() => _OptionPageState();
}

class _OptionPageState extends State<OptionPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _floatingAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth * 0.05, 
                    vertical: constraints.maxHeight * 0.06, 
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          SizedBox(height: constraints.maxHeight * 0.08), 
                          // Header Section - Pure Text
                          Column(
                            children: [
                              Text(
                                "BIENVENIDO",
                                style: TextStyle(
                                  fontSize: constraints.maxWidth * 0.08, 
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF03083A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: constraints.maxHeight * 0.01),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.02),
                                child: Text(
                                  "¿Qué te interesaría hacer dentro de nuestra aplicación?",
                                  style: TextStyle(
                                    fontSize: constraints.maxWidth * 0.04, 
                                    color: const Color(0xFF2F4157),
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: constraints.maxHeight * 0.06),
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.9, 
                              ),
                              child: Column(
                                children: [
                                  // Card 1 - Vender productos
                                  _buildOptionCard(
                                    title: 'Vender productos agrícolas',
                                    description: 'Registra tus cultivos o productos y conéctate con compradores interesados.',
                                    icon: Icons.local_florist,
                                    cardColor: const Color(0xFF4CAF50),
                                    onTap: () {
                                      // Guardar rol de vendedor
                                      UserRoleService.setUserRole(UserRoleService.sellerRole);
                                      
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ProductEstructureView(),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  SizedBox(height: constraints.maxHeight * 0.050),
                                  
                                  // Card 2 - Comprar productos
                                  _buildOptionCard(
                                    title: 'Comprar productos locales',
                                    description: 'Explora productos frescos de agricultores locales y realiza compras seguras.',
                                    icon: Icons.shopping_cart,
                                    cardColor: const Color(0xFF2F4157),
                                    onTap: () {
                                      // Guardar rol de comprador
                                      UserRoleService.setUserRole(UserRoleService.buyerRole);
                                      
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ProductEstructureView(),
                                        ),
                                      );
                                    },
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color cardColor,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Transform.translate(
              offset: Offset(0, _floatingAnimation.value),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  height: constraints.maxWidth * 0.40, 
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF577C8E).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: onTap,
                      splashColor: cardColor.withOpacity(0.1),
                      highlightColor: cardColor.withOpacity(0.05),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth * 0.04,
                          vertical: constraints.maxWidth * 0.03,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: constraints.maxWidth * 0.20,
                              height: constraints.maxWidth * 0.15,
                              decoration: BoxDecoration(
                                color: cardColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: cardColor.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                size: constraints.maxWidth * 0.09,
                                color: cardColor,
                              ),
                            ),
                            SizedBox(width: constraints.maxWidth * 0.03),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: constraints.maxWidth * 0.05,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF03083A),
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: constraints.maxWidth * 0.01),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: constraints.maxWidth * 0.03,
                                      color: const Color(0xFF2F4157).withOpacity(0.8),
                                      height: 1.6,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}