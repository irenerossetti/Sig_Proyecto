import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla de ayuda y soporte
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda'),
      ),
      body: ListView(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.headset,
                    size: 40,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Cómo podemos ayudarte?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Encuentra respuestas a tus preguntas frecuentes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // FAQ Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Preguntas frecuentes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          _FAQItem(
            question: '¿Cómo registro a mi niño?',
            answer:
                'Ve a la pestaña "Niños" y presiona el botón "+" para agregar un nuevo niño. Completa el formulario con los datos del niño y guarda los cambios.',
          ),

          _FAQItem(
            question: '¿Cómo configuro una zona segura?',
            answer:
                'En el detalle del niño, selecciona "Zonas seguras" y luego "Nueva zona". Dibuja un polígono en el mapa tocando los puntos que formarán el área y guarda la zona.',
          ),

          _FAQItem(
            question: '¿Cómo funciona el rastreo?',
            answer:
                'El dispositivo del niño (con la app GeoGuard Tracker) envía su ubicación periódicamente. Si el niño sale de una zona segura, recibirás una alerta inmediata.',
          ),

          _FAQItem(
            question: '¿Cómo configuro el dispositivo tracker?',
            answer:
                'En tu perfil encontrarás el token de autenticación. Copia este token y el ID del dispositivo asignado al niño, e ingrésalos en la app GeoGuard Tracker del dispositivo del niño.',
          ),

          _FAQItem(
            question: '¿Qué hago si no recibo alertas?',
            answer:
                'Verifica que las notificaciones estén habilitadas en la configuración de la app y en los ajustes de tu dispositivo. También asegúrate de que el dispositivo del niño tenga conexión a internet.',
          ),

          _FAQItem(
            question: '¿La batería del tracker dura todo el día?',
            answer:
                'Sí, el tracker está optimizado para funcionar todo el día escolar. Recibirás una alerta cuando la batería esté baja para que puedas cargarlo.',
          ),

          const Divider(height: 32),

          // Contact section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Contacto',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(LucideIcons.mail, color: colorScheme.primary),
            ),
            title: const Text('Correo electrónico'),
            subtitle: const Text('soporte@geoguard.app'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => _launchEmail(context),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.messageCircle, color: Colors.green),
            ),
            title: const Text('WhatsApp'),
            subtitle: const Text('+591 70000000'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => _launchWhatsApp(context),
          ),

          const Divider(height: 32),

          // About section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Acerca de',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(LucideIcons.fileText, color: colorScheme.primary),
            ),
            title: const Text('Términos y condiciones'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => _showTerms(context),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(LucideIcons.shield, color: colorScheme.primary),
            ),
            title: const Text('Política de privacidad'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => _showPrivacy(context),
          ),

          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(LucideIcons.info, color: colorScheme.primary),
            ),
            title: const Text('Versión de la app'),
            subtitle: const Text('1.0.0'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _launchEmail(BuildContext context) async {
    final uri = Uri.parse('mailto:soporte@geoguard.app?subject=Soporte GeoGuard');
    try {
      await launchUrl(uri);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el correo')),
        );
      }
    }
  }

  void _launchWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/59170000000?text=Hola, necesito ayuda con GeoGuard');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  void _showTerms(BuildContext context) {
    _showInfoDialog(
      context,
      'Términos y condiciones',
      '''
GeoGuard - Términos y Condiciones

1. Uso del servicio
GeoGuard es una aplicación diseñada para monitorear la ubicación de niños en edad preescolar. El uso del servicio está sujeto a estos términos.

2. Privacidad
Recopilamos datos de ubicación únicamente para el funcionamiento del servicio de alertas. No compartimos información con terceros.

3. Responsabilidad
GeoGuard es una herramienta de apoyo para los tutores. La supervisión directa de los niños sigue siendo responsabilidad de los adultos a cargo.

4. Dispositivos
El correcto funcionamiento depende de la conectividad y estado del dispositivo tracker. El usuario es responsable de mantener el dispositivo cargado y operativo.

5. Modificaciones
Nos reservamos el derecho de modificar estos términos con previo aviso a los usuarios.
''',
    );
  }

  void _showPrivacy(BuildContext context) {
    _showInfoDialog(
      context,
      'Política de privacidad',
      '''
GeoGuard - Política de Privacidad

Datos que recopilamos:
• Información de registro (nombre, email, teléfono)
• Datos de ubicación del dispositivo tracker
• Información de los niños registrados

Uso de los datos:
• Proporcionar el servicio de monitoreo y alertas
• Mejorar la experiencia del usuario
• Enviar notificaciones de seguridad

Seguridad:
• Los datos se transmiten de forma encriptada
• Almacenamiento seguro en servidores protegidos
• Acceso restringido solo al tutor autorizado

Derechos del usuario:
• Acceder a sus datos personales
• Solicitar la eliminación de su cuenta
• Revocar permisos de ubicación en cualquier momento

Contacto:
Para dudas sobre privacidad: privacidad@geoguard.app
''',
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  const _FAQItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ExpansionTile(
      leading: Icon(
        LucideIcons.info,
        color: colorScheme.primary,
      ),
      title: Text(
        question,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
          child: Text(
            answer,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
