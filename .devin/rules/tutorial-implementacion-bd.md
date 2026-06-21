# Tutorial y Plan de Implementación - Base de Datos RepuestosYa

## Tutorial: Estructura de la Base de Datos

### 1. Descripción General del Sistema

RepuestosYa es una plataforma de marketplace para repuestos automotrices que conecta:
- **Clientes**: Solicitan repuestos para sus vehículos
- **Almacenes/Tiendas**: Ofrecen cotizaciones para las solicitudes
- **Administradores**: Gestionan el sistema

### 2. Tipos Enumerados (Enums)

#### user_role
- `admin`: Administrador del sistema
- `cliente`: Usuario final que solicita repuestos
- `almacen`: Dueño/encargado de tienda de repuestos

#### solicitud_status
- `en_proceso`: Solicitud activa buscando cotizaciones
- `completado`: Solicitud cerrada (cotización aceptada)
- `expirado`: Solicitud sin respuesta en tiempo límite

#### cotizacion_status
- `pendiente`: Esperando respuesta del cliente
- `aceptada`: Cliente aceptó la cotización
- `rechazada`: Cliente rechazó la cotización

#### estado_repuesto
- `Nuevo (En caja original)`: Repuesto nuevo sellado
- `Nuevo (Abierto)`: Repuesto nuevo pero abierto
- `Usado (Buen estado)`: Repuesto usado en buen estado

### 3. Tablas Maestras (Catálogos en 3FN)

#### marcas_vehiculo
- Catálogo de marcas de vehículos (Toyota, Honda, Ford, etc.)
- Relación uno-a-muchos con modelos_vehiculo
- **Campos**: id, nombre

#### modelos_vehiculo
- Catálogo de modelos por marca (Corolla, Civic, F-150, etc.)
- Relación muchos-a-uno con marcas_vehiculo
- **Campos**: id, marca_id, nombre
- **Restricción**: Un modelo no puede repetirse en la misma marca

### 4. Tablas Principales

#### profiles
- Espejo de `auth.users` de Supabase
- Almacena información extendida del usuario
- **Campos**: id, nombre_completo, email, telefono, rol, tipo_membresia, avatar_url, created_at, updated_at
- **Trigger**: Se crea automáticamente cuando un usuario se registra en Supabase Auth

#### vehiculos_cliente
- Vehículos registrados por los clientes
- Relación muchos-a-uno con profiles
- Relación muchos-a-uno con modelos_vehiculo
- **Campos**: id, cliente_id, modelo_id, anio, vin, created_at

#### direcciones_entrega
- Ubicaciones de entrega para los clientes
- Incluye coordenadas geográficas para cálculo de distancia
- **Campos**: id, cliente_id, nombre_ubicacion, direccion_texto, latitude, longitude, created_at
- **Validación**: Latitud entre -90 y 90, Longitud entre -180 y 180

#### almacenes
- Tiendas/almacenes de repuestos registrados
- Relación muchos-a-uno con profiles (encargado)
- **Campos**: id, encargado_id, nombre_comercial, direccion_texto, latitude, longitude, verificado, estado_abierto, created_at

#### solicitudes_repuesto
- Solicitudes creadas por clientes buscando repuestos
- Relación muchos-a-uno con profiles (cliente)
- Relación muchos-a-uno con vehiculos_cliente
- Relación muchos-a-uno con direcciones_entrega
- **Campos**: id, cliente_id, vehiculo_id, pieza_nombre, descripcion, foto_url, vin_busqueda, direccion_entrega_id, estado, es_urgente, vistas_contador, created_at, updated_at

#### cotizaciones
- Ofertas de precio enviadas por almacenes
- Relación muchos-a-uno con solicitudes_repuesto
- Relación muchos-a-uno con almacenes
- **Campos**: id, solicitud_id, almacen_id, precio_venta, comision_plataforma (calculada 5%), condicion_repuesto, foto_evidencia_url, notas_adicionales, tiempo_entrega_estimado, estado, created_at
- **Constraint**: precio_venta debe ser positivo

### 5. Funciones y Triggers

#### handle_new_user()
- Trigger que se ejecuta al crear un usuario en `auth.users`
- Crea automáticamente un registro en `profiles`
- Asigna rol por defecto: 'cliente'
- Asigna membresía por defecto: 'Regular Member'

#### calcular_distancia(lat1, lon1, lat2, lon2)
- Calcula distancia en kilómetros entre dos coordenadas geográficas
- Usa fórmula Haversine
- Retorna distancia redondeada a 1 decimal
- Marca como IMMUTABLE para optimización

#### get_user_role()
- Función auxiliar para seguridad RLS
- Retorna el rol del usuario autenticado
- Evita bucles recursivos en políticas RLS

### 6. Row Level Security (RLS)

#### Políticas por Rol

**Clientes:**
- Lectura pública de perfiles
- Actualización de su propio perfil
- Gestión completa de sus vehículos
- Gestión completa de sus direcciones
- Control total de sus solicitudes
- Lectura de cotizaciones recibidas

**Almacenes:**
- Lectura de todos los almacenes (para mapa)
- Creación y actualización de su propio perfil
- Lectura de solicitudes activas (en_proceso)
- Gestión completa de sus cotizaciones

**Administradores:**
- Control total de todas las tablas

### 7. Diagrama de Relaciones

```
auth.users (Supabase Auth)
    ↓ (1:1)
profiles
    ↓ (1:N)
    ├── vehiculos_cliente → modelos_vehiculo → marcas_vehiculo
    ├── direcciones_entrega
    └── almacenes (si rol = almacen)
            ↓ (1:N)
            cotizaciones → solicitudes_repuesto → direcciones_entrega
                         → vehiculos_cliente
```

---

## Plan de Implementación

### Fase 1: Preparación del Entorno (Día 1)

#### 1.1 Crear Proyecto Supabase
- Crear cuenta en Supabase (si no existe)
- Crear nuevo proyecto llamado "repuestosya"
- Seleccionar región más cercana a los usuarios principales
- Obtener `project_id` y `project_url`

#### 1.2 Configurar Autenticación
- Habilitar email/password authentication
- Configurar confirmación de email (opcional)
- Generar API keys (anon y service_role)
- Guardar credenciales en variables de entorno

#### 1.3 Preparar Entorno Local
- Instalar CLI de Supabase: `npm install -g supabase`
- Inicializar proyecto local: `supabase init`
- Conectar al proyecto remoto: `supabase link --project-ref <project-id>`

### Fase 2: Implementación del Esquema (Día 2)

#### 2.1 Crear Archivo de Migración
```bash
supabase migration new inicializar_esquema_repuestosya
```

#### 2.2 Ejecutar Script SQL
- Copiar contenido de `bd-repuestosya-tablas.md`
- Pegar en el archivo de migración generado
- Revisar sintaxis SQL
- Ejecutar migración:
```bash
supabase db push
```

#### 2.3 Verificar Creación de Tablas
- Usar Supabase Dashboard → Table Editor
- Verificar que todas las tablas existen:
  - marcas_vehiculo
  - modelos_vehiculo
  - profiles
  - vehiculos_cliente
  - direcciones_entrega
  - almacenes
  - solicitudes_repuesto
  - cotizaciones

#### 2.4 Verificar Enums
- Usar SQL Editor en Dashboard
- Ejecutar: `SELECT enumlabel FROM pg_enum WHERE enumtypid = 'user_role'::regtype`
- Repetir para otros enums

### Fase 3: Carga de Datos Iniciales (Día 3)

#### 3.1 Poblar Catálogo de Marcas
```sql
INSERT INTO marcas_vehiculo (nombre) VALUES
('Toyota'), ('Honda'), ('Ford'), ('Chevrolet'), ('Nissan'),
('Volkswagen'), ('BMW'), ('Mercedes-Benz'), ('Hyundai'), ('Kia');
```

#### 3.2 Poblar Catálogo de Modelos
```sql
INSERT INTO modelos_vehiculo (marca_id, nombre) VALUES
(1, 'Corolla'), (1, 'Camry'), (1, 'RAV4'),
(2, 'Civic'), (2, 'Accord'), (2, 'CR-V'),
(3, 'F-150'), (3, 'Mustang'), (3, 'Explorer');
```

#### 3.3 Crear Usuario Admin
- Registrar usuario en Supabase Auth
- Actualizar rol a admin en tabla profiles:
```sql
UPDATE profiles SET rol = 'admin' WHERE email = 'admin@repuestosya.com';
```

### Fase 4: Integración con Flutter (Día 4-5)

#### 4.1 Instalar Dependencias
```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.0.0
```

#### 4.2 Configurar Supabase Client
```dart
// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'YOUR_SUPABASE_URL',
      anonKey: 'YOUR_SUPABASE_ANON_KEY',
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}
```

#### 4.3 Implementar Servicio de Autenticación
- Extender `auth_service.dart` existente
- Integrar con Supabase Auth
- Manejar registro, login, logout

#### 4.4 Crear Repositorios de Datos
- `profile_repository.dart`: CRUD de perfiles
- `vehiculo_repository.dart`: Gestión de vehículos
- `almacen_repository.dart`: Gestión de almacenes
- `solicitud_repository.dart`: Gestión de solicitudes
- `cotizacion_repository.dart`: Gestión de cotizaciones

### Fase 5: Implementación de Funcionalidades (Día 6-10)

#### 5.1 Registro de Usuarios
- Implementar formulario de registro
- Capturar nombre_completo en metadata
- Verificar creación automática en profiles

#### 5.2 Gestión de Vehículos
- Pantalla para agregar vehículo
- Selector de marca y modelo
- Validación de año y VIN

#### 5.3 Gestión de Direcciones
- Pantalla para agregar dirección
- Integración con geocoding (lat/long)
- Validación de coordenadas

#### 5.4 Creación de Solicitudes
- Formulario de solicitud de repuesto
- Selección de vehículo y dirección
- Opción de marcar como urgente
- Subida de foto (opcional)

#### 5.5 Registro de Almacenes
- Flujo de registro para tiendas
- Captura de ubicación geográfica
- Verificación manual por admin

#### 5.6 Sistema de Cotizaciones
- Almacenes ven solicitudes activas
- Envío de cotizaciones con precio
- Cálculo automático de comisión (5%)
- Clientes aceptan/rechazan cotizaciones

### Fase 6: Pruebas y Validación (Día 11-12)

#### 6.1 Pruebas de Seguridad RLS
- Verificar que clientes no ven datos de otros clientes
- Verificar que almacenes solo ven solicitudes activas
- Verificar que admin tiene acceso total

#### 6.2 Pruebas Funcionales
- Flujo completo: Registro → Agregar vehículo → Crear solicitud → Recibir cotización → Aceptar
- Verificar cálculo de distancia entre almacén y dirección
- Verificar cálculo automático de comisión

#### 6.3 Pruebas de Edge Cases
- Eliminar usuario y verificar CASCADE
- Intentar cotización con precio negativo (debe fallar)
- Coordenadas geográficas inválidas (deben fallar)

### Fase 7: Despliegue (Día 13)

#### 7.1 Configuración de Producción
- Actualizar variables de entorno
- Verificar políticas RLS en producción
- Configurar backups automáticos

#### 7.2 Monitoreo
- Habilitar logs de Supabase
- Configurar alertas de errores
- Monitorear rendimiento de consultas

#### 7.3 Documentación
- Documentar API endpoints
- Crear guía para desarrolladores
- Documentar estructura de base de datos

---

## Checklist de Implementación

### Pre-Implementación
- [ ] Cuenta de Supabase creada
- [ ] Proyecto "repuestosya" creado
- [ ] CLI de Supabase instalado
- [ ] Variables de entorno configuradas

### Esquema de Base de Datos
- [ ] Migración creada
- [ ] Script SQL ejecutado
- [ ] Todas las tablas verificadas
- [ ] Todos los enums verificados
- [ ] Triggers creados
- [ ] Funciones creadas
- [ ] RLS activado
- [ ] Políticas RLS verificadas

### Datos Iniciales
- [ ] Marcas de vehículos cargadas
- [ ] Modelos de vehículos cargados
- [ ] Usuario admin creado

### Integración Flutter
- [ ] Dependencias instaladas
- [ ] Supabase client configurado
- [ ] Auth service integrado
- [ ] Repositorios creados

### Funcionalidades
- [ ] Registro de usuarios
- [ ] Gestión de vehículos
- [ ] Gestión de direcciones
- [ ] Creación de solicitudes
- [ ] Registro de almacenes
- [ ] Sistema de cotizaciones

### Pruebas
- [ ] Pruebas de seguridad RLS
- [ ] Pruebas funcionales
- [ ] Pruebas de edge cases

### Despliegue
- [ ] Configuración de producción
- [ ] Monitoreo configurado
- [ ] Documentación completa

---

## Comandos Útiles

### Supabase CLI
```bash
# Inicializar proyecto
supabase init

# Conectar a proyecto remoto
supabase link --project-ref <project-id>

# Crear migración
supabase migration new <nombre>

# Aplicar migraciones
supabase db push

# Generar tipos TypeScript
supabase gen types typescript

# Ver logs
supabase functions logs

# Acceder a base de datos local
supabase db reset
```

### Consultas SQL de Verificación
```sql
-- Ver todas las tablas
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public';

-- Ver todos los enums
SELECT typname FROM pg_type WHERE typtype = 'e';

-- Ver políticas RLS
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public';

-- Ver triggers
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'public';
```

---

## Recursos Adicionales

- [Documentación de Supabase](https://supabase.com/docs)
- [Guía de RLS](https://supabase.com/docs/guides/auth/row-level-security)
- [Flutter Supabase Plugin](https://pub.dev/packages/supabase_flutter)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
