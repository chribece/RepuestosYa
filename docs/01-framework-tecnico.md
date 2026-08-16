# Detalle Técnico del Framework - RepuestosYa

## 1. Arquitectura General del Proyecto

RepuestosYa es una plataforma de marketplace de repuestos automotrices que utiliza una arquitectura multicapa con tres componentes principales:

1. **Aplicación Móvil Flutter** - Frontend para clientes
2. **Panel de Administración Next.js** - Interfaz de gestión para administradores
3. **Backend Express.js** - API REST y lógica de negocio

## 2. Framework Flutter (Aplicación Móvil)

### 2.1 Características Principales

- **Framework**: Flutter 3.12.1+
- **Lenguaje**: Dart
- **Arquitectura**: Widget Tree + Provider Pattern
- **Plataformas**: Android, iOS (multiplataforma)

### 2.2 Dependencias Principales

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.1              # State management
  image_picker: ^1.0.7          # Captura de imágenes
  http: ^1.1.0                  # Cliente HTTP
  shared_preferences: ^2.2.2    # Almacenamiento local
  cached_network_image: ^3.3.1  # Caché de imágenes
  supabase_flutter: ^2.0.0     # Cliente Supabase
  flutter_local_notifications: ^17.2.2  # Notificaciones locales
  permission_handler: ^11.3.1   # Permisos del sistema
  device_info_plus: ^10.1.0     # Información del dispositivo
```

### 2.3 Estructura de Directorios Flutter

```
lib/
├── main.dart                   # Punto de entrada
├── app.dart                    # Configuración global
├── models/                     # Modelos de datos
│   ├── vehiculo.dart
│   ├── solicitud.dart
│   └── cotizacion.dart
├── providers/                  # State management
│   ├── auth_provider.dart
│   ├── vehiculo_provider.dart
│   └── solicitud_provider.dart
├── services/                   # Servicios y API
│   ├── api_service.dart
│   ├── auth_service.dart
│   └── supabase_service.dart
├── screens/                    # Pantallas de la app
│   ├── home/
│   ├── auth/
│   ├── solicitudes/
│   └── perfil/
├── widgets/                    # Componentes reutilizables
│   ├── custom_button.dart
│   ├── loading_indicator.dart
│   └── image_upload.dart
└── utils/                      # Utilidades
    ├── constants.dart
    ├── validators.dart
    └── helpers.dart
```

### 2.4 Configuración del Entorno

**Requisitos Previos:**
- Flutter SDK 3.12.1 o superior
- Dart SDK 3.12.1 o superior
- Android Studio / Xcode
- Emulador o dispositivo físico

**Comandos de Desarrollo:**
```bash
# Instalar dependencias
flutter pub get

# Ejecutar aplicación
flutter run

# Compilar para Android
flutter build apk

# Compilar para iOS
flutter build ios
```

### 2.5 Patrones de Estado

**Provider Pattern:**
- Gestión de estado reactiva
- Inyección de dependencias
- Separación de lógica de negocio de la UI

**Ejemplo de Provider:**
```dart
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _user = await AuthService.login(email, password);
    } catch (e) {
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

## 3. Framework Next.js (Panel de Administración)

### 3.1 Características Principales

- **Framework**: Next.js 14.2.0
- **Lenguaje**: TypeScript
- **Arquitectura**: App Router (Next.js 13+)
- **Estilos**: Tailwind CSS 3.4.0
- **UI Components**: React 18.3.0

### 3.2 Dependencias Principales

```json
{
  "dependencies": {
    "next": "^14.2.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "lucide-react": "^0.378.0",  // Iconos
    "recharts": "^2.12.0"       // Gráficos
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0"
  }
}
```

### 3.3 Estructura de Directorios Next.js

```
admin-panel/
├── src/
│   ├── app/                     # App Router
│   │   ├── layout.tsx          # Layout raíz
│   │   ├── page.tsx            # Página de inicio
│   │   ├── login/              # Autenticación
│   │   ├── dashboard/          # Dashboard principal
│   │   ├── orders/             # Gestión de órdenes
│   │   ├── users/              # Gestión de usuarios
│   │   └── warehouses/         # Gestión de almacenes
│   ├── components/             # Componentes reutilizables
│   │   ├── Sidebar.tsx
│   │   ├── Header.tsx
│   │   └── DataTable.tsx
│   ├── lib/                    # Utilidades
│   │   ├── api.ts              # Cliente API
│   │   ├── auth.ts             # Autenticación
│   │   └── utils.ts
│   └── types/                  # Tipos TypeScript
│       └── index.ts
├── public/                     # Assets estáticos
├── tailwind.config.ts          # Configuración Tailwind
├── next.config.js              # Configuración Next.js
└── tsconfig.json               # Configuración TypeScript
```

### 3.4 Configuración del Entorno

**Requisitos Previos:**
- Node.js 18.17 o superior
- npm o yarn
- TypeScript 5.4.0

**Comandos de Desarrollo:**
```bash
# Instalar dependencias
npm install

# Ejecutar en modo desarrollo
npm run dev

# Compilar para producción
npm run build

# Iniciar servidor de producción
npm start
```

### 3.5 Características de Next.js Utilizadas

**App Router:**
- Sistema de rutas basado en archivos
- Layouts anidados
- Server Components por defecto

**TypeScript:**
- Tipado estático
- Interfaces para modelos de datos
- Autocompletado y detección de errores

**Tailwind CSS:**
- Utility-first CSS
- Diseño responsivo
- Temas personalizados

## 4. Framework Express.js (Backend API)

### 4.1 Características Principales

- **Framework**: Express.js 4.18.2
- **Lenguaje**: JavaScript (Node.js)
- **Arquitectura**: MVC (Model-View-Controller)
- **Base de Datos**: Supabase (PostgreSQL)
- **Autenticación**: JWT (JSON Web Tokens)

### 4.2 Dependencias Principales

```json
{
  "dependencies": {
    "express": "^4.18.2",
    "@supabase/supabase-js": "^2.38.4",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "jsonwebtoken": "^9.0.2",
    "dotenv": "^16.3.1",
    "morgan": "^1.11.0",
    "express-rate-limit": "^7.1.5",
    "bullmq": "^5.80.6",         // Colas de trabajos
    "ioredis": "^5.11.1",        // Cliente Redis
    "multer": "^2.2.0"           // Upload de archivos
  }
}
```

### 4.3 Estructura de Directorios Backend

```
backend/
├── src/
│   ├── controllers/            # Controladores
│   │   ├── authController.js
│   │   ├── vehiculoController.js
│   │   ├── solicitudController.js
│   │   ├── cotizacionController.js
│   │   ├── adminController.js
│   │   └── almacenController.js
│   ├── middleware/             # Middleware
│   │   ├── auth.js             # Autenticación JWT
│   │   └── timing.js           # Medición de tiempo
│   ├── routes/                 # Rutas
│   │   └── index.js            # Router principal
│   ├── services/               # Servicios de negocio
│   │   ├── supabase.js         # Cliente Supabase
│   │   ├── cache.js            # Caché Redis
│   │   ├── ordenService.js
│   │   └── cotizacionService.js
│   ├── queues/                 # Colas de trabajo
│   │   └── notificaciones.queue.js
│   └── workers/                # Workers de background
│       └── notificaciones.worker.js
├── migrations/                 # Migraciones SQL
│   ├── add_ordenes_compra_and_cotizacion_workflow.sql
│   ├── add_warehouse_fields.sql
│   └── fix_profiles_rls.sql
├── scripts/                    # Scripts de utilidad
│   ├── apply_rls_fix.js
│   └── apply_rls_simple.js
├── server.js                   # Punto de entrada
└── package.json
```

### 4.4 Configuración del Entorno

**Requisitos Previos:**
- Node.js 18.17 o superior
- npm o yarn
- Cuenta de Supabase
- Redis (opcional, para colas)

**Comandos de Desarrollo:**
```bash
# Instalar dependencias
npm install

# Ejecutar en modo desarrollo
npm run dev

# Ejecutar worker de notificaciones
npm run worker

# Iniciar servidor de producción
npm start
```

### 4.5 Variables de Entorno

```env
# Configuración Supabase
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Configuración JWT
JWT_SECRET=your_jwt_secret
JWT_EXPIRES_IN=24h

# Configuración Servidor
PORT=3000
NODE_ENV=development

# Configuración Redis (opcional)
REDIS_HOST=localhost
REDIS_PORT=6379
```

## 5. Integración entre Frameworks

### 5.1 Comunicación Flutter ↔ Backend

- **Protocolo**: HTTP/REST
- **Formato**: JSON
- **Autenticación**: JWT Bearer Token
- **Base URL**: `http://localhost:3000/api`

**Ejemplo de llamada desde Flutter:**
```dart
final response = await http.get(
  Uri.parse('$baseUrl/api/marcas'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
);
```

### 5.2 Comunicación Next.js ↔ Backend

- **Protocolo**: HTTP/REST
- **Formato**: JSON
- **Autenticación**: JWT Bearer Token
- **Base URL**: `http://localhost:3000/api`

**Ejemplo de llamada desde Next.js:**
```typescript
const response = await fetch(`${API_URL}/api/users`, {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
  },
});
```

### 5.3 Comunicación Backend ↔ Supabase

- **Protocolo**: Supabase Client SDK
- **Autenticación**: Supabase Auth
- **Database**: PostgreSQL
- **Realtime**: WebSockets (opcional)

**Ejemplo de conexión Supabase:**
```javascript
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);
```

## 6. Ventajas de la Arquitectura Multiframe

### 6.1 Especialización por Componente

- **Flutter**: Optimizado para experiencias móviles nativas
- **Next.js**: Optimizado para dashboards web con SSR
- **Express.js**: Optimizado para APIs REST escalables

### 6.2 Independencia de Desarrollo

- Los equipos pueden trabajar en paralelo
- Cambios en un componente no afectan directamente a otros
- Posibilidad de escalar componentes independientemente

### 6.3 Flexibilidad Tecnológica

- Uso de las mejores herramientas para cada caso
- Posibilidad de migrar componentes individualmente
- Adopción de nuevas tecnologías por componente

## 7. Consideraciones de Seguridad

### 7.1 Autenticación y Autorización

- **JWT Tokens**: Para autenticación stateless
- **RLS (Row Level Security)**: En Supabase para seguridad a nivel de datos
- **Role-based Access Control**: Roles definidos (admin, cliente, almacen)

### 7.2 Seguridad de Datos

- **HTTPS**: En producción
- **Helmet.js**: Headers de seguridad HTTP
- **Rate Limiting**: Protección contra ataques DDoS
- **Input Validation**: Validación de datos en backend

### 7.3 Variables de Entorno

- Secrets almacenados en `.env`
- Nunca commits de credenciales
- Rotación de claves regular

## 8. Monitoreo y Logging

### 8.1 Logging

- **Morgan**: Logging de peticiones HTTP
- **Timing Middleware**: Medición de tiempo de respuesta
- **Custom Logs**: Logs de errores y eventos importantes

### 8.2 Métricas

- **Response Time**: Tiempo de respuesta de endpoints
- **Error Rate**: Tasa de errores
- **Request Count**: Conteo de peticiones
- **Database Queries**: Rendimiento de consultas

## 9. Escalabilidad

### 9.1 Escalabilidad Horizontal

- **Backend**: Puede ser escalado con load balancers
- **Database**: Supabase maneja escalabilidad automáticamente
- **Next.js**: Puede ser desplegado en Vercel con escalabilidad automática

### 9.2 Escalabilidad Vertical

- **Code Splitting**: En Next.js para optimizar carga
- **Lazy Loading**: En Flutter para mejor rendimiento
- **Database Indexing**: Índices optimizados en Supabase

## 10. Recursos y Documentación

### 10.1 Documentación Oficial

- **Flutter**: https://docs.flutter.dev/
- **Next.js**: https://nextjs.org/docs
- **Express.js**: https://expressjs.com/
- **Supabase**: https://supabase.com/docs

### 10.2 Comunidades

- **Flutter**: https://flutter.dev/community
- **Next.js**: https://nextjs.org/community
- **Express.js**: https://expressjs.com/community
- **Supabase**: https://supabase.com/community