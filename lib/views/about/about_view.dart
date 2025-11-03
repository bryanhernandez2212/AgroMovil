import 'package:flutter/material.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header
              const Center(
                child: Text(
                  "Acerca de Nosotros",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115213),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Título del equipo
              const Text(
                "Nuestro Equipo",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF115213),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Lista de integrantes
              ..._buildTeamMembers(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTeamMembers() {
    final teamMembers = [
      {
        'name': 'Bryan Hernández',
        'role': 'Desarrollor',
        'description': 'Desarrollo Móvil Integral',
        'icon': Icons.code,
      },
      {
        'name': 'Evelyn Pérez',
        'role': 'Desarrolladora',
        'description': 'Desarrollo Móvil Integral',
        'icon': Icons.design_services,
      },
      {
        'name': 'Noemisabel Zavala',
        'role': 'Desarrolladora',
        'description': 'Desarrollo Móvil Integral',
        'icon': Icons.storage,
      },
      {
        'name': 'Cristian Trujillo',
        'role': 'Desarrollador',
        'description': 'Desarrollo Móvil Integral',
        'icon': Icons.integration_instructions,
      },
      {
        'name': 'Gerardo Velasco',
        'role': 'Desarrollador',
        'description': 'Desarrollo Móvil Integral',
        'icon': Icons.phone_android,
      },
    ];

    return teamMembers.map((member) => _buildMemberCard(member)).toList();
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF115213),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF115213).withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              member['icon'],
              color: Colors.white,
              size: 30,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Información del miembro
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF115213),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member['role'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  member['description'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
