# RepuestosYa

Plataforma de marketplace de repuestos automotrices que conecta clientes que necesitan repuestos con almacenes y tiendas que ofrecen cotizaciones.

## 🏗️ Arquitectura del Proyecto

RepuestosYa es una aplicación multicapa compuesta por tres componentes principales:

### 📱 Aplicación Móvil (Flutter)
- **Framework**: Flutter 3.12.1+
- **Lenguaje**: Dart
- **Funcionalidad**: Interfaz para clientes y almacenes
- **Características**: 
  - Gestión de vehículos y solicitudes de repuestos
  - Sistema de cotizaciones en tiempo real
  - Notificaciones push
  - Subida y visualización de imágenes

### 🖥️ Panel de Administración (Next.js)
- **Framework**: Next.js 14.2.0
- **Lenguaje**: TypeScript
- **Funcionalidad**: Dashboard para administradores
- **Características**:
  - Gestión de usuarios y roles
  - Monitoreo de órdenes y métricas
  - Verificación de almacenes
  - Análisis de datos

### 🔌 Backend API (Express.js)
- **Framework**: Express.js 4.18.2
- **Lenguaje**: JavaScript (Node.js)
- **Base de Datos**: PostgreSQL (Supabase)
- **Características**:
  - API REST completa
  - Autenticación JWT
  - Sistema de colas (BullMQ)
  - Caché Redis

## 🚀 Características Principales

### Para Clientes
- Registro y gestión de vehículos
- Solicitud de repuestos específicos
- Creación de solicitudes **sin conexión** (Outbox) con sincronización automática al reconectar
- Recepción de cotizaciones de múltiples almacenes
- Seguimiento de órdenes de compra
- Geolocalización para direcciones de entrega

### Para Almacenes
- Registro y verificación de negocio
- Acceso a solicitudes de repuestos activas
- Dashboard con **recarga automática al recuperar la conexión** (aviso incluido)
- Activación automática del feed de solicitudes al ser **aprobado por el admin** (≤ 10 s)
- Envío de cotizaciones con fotos y precios
- Gestión de órdenes de compra
- Dashboard de métricas y rendimiento

### Para Administradores
- Gestión de usuarios y roles
- Verificación de almacenes
- Monitoreo de métricas globales
- Gestión de configuración del sistema

## 📁 Estructura del Proyecto

```
RepuestosYa/
├── lib/                      # Aplicación Flutter
│   ├── models/              # Modelos de datos
│   ├── providers/           # State management
│   ├── services/            # Servicios API
│   ├── pages/               # Pantallas de la app
│   └── widgets/             # Componentes UI
├── admin-panel/             # Panel Next.js
│   ├── src/
│   │   ├── app/            # App Router
│   │   ├── components/     # Componentes React
│   │   └── lib/            # Utilidades
│   └── package.json
├── backend/                 # API Express.js
│   ├── src/
│   │   ├── controllers/    # Controladores HTTP
│   │   ├── middleware/     # Middleware
│   │   ├── routes/         # Definición de rutas
│   │   └── services/       # Servicios de negocio
│   ├── migrations/         # Migraciones SQL
│   └── package.json
├── docs/                    # Documentación técnica
│   ├── 01-framework-tecnico.md
│   ├── 02-mvc-architecture.md
│   ├── 03-backend-tecnico.md
│   ├── 04-git-repositorio.md
│   ├── 05-documentacion-tecnica.md
│   └── AUDITORIA_SEGURIDAD.md  # Auditoría de red, persistencia y seguridad
├── .devin/                  # Configuración Devin AI
├── API_DOCUMENTATION.md     # Documentación API REST
└── README.md               # Este archivo
```

## 🛠️ Tecnologías Utilizadas

### Frontend Móvil
- **Flutter**: Framework multiplataforma
- **Provider**: State management
- **Supabase Flutter**: Cliente de base de datos
- **HTTP**: Cliente API
- **Image Picker**: Captura de imágenes

### Frontend Web
- **Next.js**: Framework React con SSR
- **TypeScript**: Tipado estático
- **Tailwind CSS**: Estilos utility-first
- **Lucide React**: Iconos
- **Recharts**: Gráficos y visualizaciones

### Backend
- **Express.js**: Framework web
- **Supabase**: Base de datos PostgreSQL y autenticación
- **JWT**: Autenticación de tokens
- **BullMQ**: Sistema de colas
- **Redis**: Caché y cola de mensajes
- **Helmet**: Seguridad HTTP

## 📖 Documentación

Para documentación técnica detallada, consulta la carpeta [`docs/`](./docs/):

- **[Framework Técnico](./docs/01-framework-tecnico.md)**: Detalles de frameworks y tecnologías
- **[Arquitectura MVC](./docs/02-mvc-architecture.md)**: Estructura del software
- **[Backend Técnico](./docs/03-backend-tecnico.md)**: Detalles del backend API
- **[Git y Repositorio](./docs/04-git-repositorio.md)**: Gestión de versiones
- **[Documentación Técnica](./docs/05-documentacion-tecnica.md)**: Metadocumentación

Documentación adicional:
- **[API Documentation](./API_DOCUMENTATION.md)**: Endpoints y ejemplos de API REST
- **[Auditoría de Seguridad](./docs/AUDITORIA_SEGURIDAD.md)**: Auditoría de la capa de red, persistencia y seguridad (hallazgos, correcciones B1–B8 y brechas pendientes)
- **[Base de Datos](./.devin/rules/bd-repuestosya-tablas.md)**: Esquema de base de datos
- **[Tutorial Implementación](./.devin/rules/tutorial-implementacion-bd.md)**: Guía de implementación

## 🚦 Getting Started

### Requisitos Previos

- **Node.js** 18.17+ (para backend y admin panel)
- **Flutter** 3.12.1+ (para app móvil)
- **Cuenta de Supabase** (base de datos y autenticación)
- **Redis** (opcional, para caché y colas)

### Instalación

1. **Clonar el repositorio**
```bash
git clone https://github.com/chribece/RepuestosYa.git
cd RepuestosYa
```

2. **Configurar Backend**
```bash
cd backend
npm install
cp .env.example .env
# Configurar variables de entorno en .env
npm run dev
```

3. **Configurar Panel de Administración**
```bash
cd admin-panel
npm install
cp .env.example .env.local
# Configurar variables de entorno
npm run dev
```

4. **Configurar Aplicación Móvil**
```bash
# Desde la raíz del proyecto
flutter pub get
flutter run
```

### Variables de Entorno

Crea archivos `.env` en los directorios correspondientes:

**Backend (.env):**
```env
PORT=3000
NODE_ENV=development
ALLOWED_ORIGINS=https://app.repuestosya.com,https://admin.repuestosya.com  # CORS en producción (separado por comas)
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key     # Requerida por /auth/refresh (nunca usar la service-role key en endpoints públicos)
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key  # Solo operaciones server-side (bypass de RLS)
JWT_SECRET=your_jwt_secret
JWT_EXPIRES_IN=24h
```

> Referencia completa: `backend/.env.example`

**Admin Panel (.env.local):**
```env
NEXT_PUBLIC_API_URL=http://localhost:3000/api
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

## 🧪 Testing

### Backend
```bash
cd backend
npm test
```

### Flutter
```bash
flutter test
```

### Admin Panel
```bash
cd admin-panel
npm test
```

## 📊 Base de Datos

El proyecto utiliza **Supabase** (PostgreSQL) con las siguientes tablas principales:

- **profiles**: Perfiles de usuarios
- **vehiculos_cliente**: Vehículos registrados
- **direcciones_entrega**: Ubicaciones de entrega
- **almacenes**: Tiendas de repuestos
- **solicitudes_repuesto**: Solicitudes de clientes
- **cotizaciones**: Ofertas de almacenes
- **ordenes_compra**: Órdenes confirmadas
- **marcas_vehiculo**: Catálogo de marcas
- **modelos_vehiculo**: Catálogo de modelos

Para más detalles, consulta [`.devin/rules/bd-repuestosya-tablas.md`](./.devin/rules/bd-repuestosya-tablas.md)

## 🔐 Seguridad

- **Autenticación**: JWT tokens + Supabase Auth, con renovación automática (single-flight) y cierre de sesión ante 401
- **Autorización**: Role-based access control (admin, cliente, almacen) + protección de rutas por rol en el router
- **Almacenamiento de tokens**: `flutter_secure_storage` (Keystore Android / Keychain iOS); sesión cifrada
- **RLS**: Row Level Security en Supabase
- **CORS**: Switch por ambiente — allowlist de desarrollo en dev; en producción se lee de `ALLOWED_ORIGINS` (comma-separated)
- **Rate Limiting**: Por capas — `authLimiter` (20 intentos/15 min, compartido login/register/refresh) + `apiLimiter` (300 req/15 min)
- **Error handler**: En producción responde `{"error":"Internal server error"}` — nunca filtra mensajes internos ni stack traces
- **`/auth/refresh`**: Usa exclusivamente `SUPABASE_ANON_KEY`; sin ella falla cerrado (nunca degrada a service-role key)
- **Logging**: `console.*` y morgan restringidos en producción (`:method :url :status`); logger de la app solo en `kDebugMode`
- **Helmet**: Headers de seguridad HTTP

> Detalle completo, correcciones aplicadas (B1–B8) y brechas pendientes en [docs/AUDITORIA_SEGURIDAD.md](./docs/AUDITORIA_SEGURIDAD.md)

## 🌐 API Endpoints

La API REST está disponible en `http://localhost:3000/api`

**Endpoints principales:**
- `POST /api/auth/login` - Inicio de sesión
- `POST /api/auth/register` - Registro de usuarios
- `GET /api/vehicles` - Obtener vehículos
- `POST /api/vehicles` - Crear vehículo
- `GET /api/requests` - Obtener solicitudes
- `POST /api/requests` - Crear solicitud
- `POST /api/quotations` - Crear cotización
- `GET /api/admin/metrics` - Métricas del dashboard

Para documentación completa de la API, consulta [`API_DOCUMENTATION.md`](./API_DOCUMENTATION.md)

## 🔄 Flujo de Trabajo de Desarrollo

1. **Crear rama de funcionalidad**
```bash
git checkout -b feature/nueva-funcionalidad
```

2. **Realizar cambios con commits atómicos**
```bash
git add .
git commit -m "feat: descripción de la funcionalidad"
```

3. **Push y crear Pull Request**
```bash
git push origin feature/nueva-funcionalidad
```

4. **Code review y merge**

Para más detalles sobre el flujo de trabajo Git, consulta [`docs/04-git-repositorio.md`](./docs/04-git-repositorio.md)

## 📈 Monitoreo y Métricas

### Performance
- **Backend**: Timing middleware para medir response time
- **Caché**: Métricas de hit/miss ratio
- **Database**: Query time optimization

### Logging
- **Morgan**: Logging de peticiones HTTP
- **Custom logs**: Errores y eventos importantes
- **Error tracking**: Integración con Sentry (opcional)

## 🚀 Despliegue

### Backend
```bash
cd backend
npm run build
npm start
```

### Admin Panel
```bash
cd admin-panel
npm run build
npm start
```

### Aplicación Móvil
```bash
# Android
flutter build apk

# iOS
flutter build ios
```

## 🤝 Contribución

1. Fork el proyecto
2. Crear rama para tu funcionalidad (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'feat: Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abrir un Pull Request

## 📝 Convenciones de Commits

Seguimos el formato [Conventional Commits](https://www.conventionalcommits.org/):

- `feat`: Nueva funcionalidad
- `fix`: Corrección de bug
- `docs`: Cambios en documentación
- `style`: Cambios de formato
- `refactor`: Refactorización
- `perf`: Mejoras de performance
- `test`: Tests
- `chore`: Cambios en herramientas

## 📄 Licencia

Este proyecto está bajo la Licencia ISC.

## 👥 Equipo

- **Desarrollo**: Equipo de desarrollo de RepuestosYa
- **Arquitectura**: Diseño de sistemas y base de datos
- **UI/UX**: Diseño de interfaces y experiencia de usuario

## 📞 Soporte

Para soporte y preguntas:
- **Issues**: [GitHub Issues](https://github.com/chribece/RepuestosYa/issues)
- **Documentación**: [`docs/`](./docs/)
- **API Docs**: [`API_DOCUMENTATION.md`](./API_DOCUMENTATION.md)

## 🙏 Agradecimientos

- **Flutter Team**: Por el excelente framework multiplataforma
- **Supabase**: Por la plataforma de base de datos y autenticación
- **Next.js Team**: Por el framework React con SSR
- **Comunidad Open Source**: Por las herramientas y librerías utilizadas

---

**Nota**: Este proyecto está en desarrollo activo. La documentación y el código están sujetos a cambios frecuentes.