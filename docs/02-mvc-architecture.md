# Detalle Técnico del Software a Nivel MVC - RepuestosYa

## 1. Arquitectura MVC General

RepuestosYa implementa el patrón **Model-View-Controller (MVC)** en sus tres componentes principales, adaptándolo a las características específicas de cada framework:

1. **Backend Express.js**: MVC clásico con separación clara de responsabilidades
2. **Flutter**: Adaptación de MVC con Provider Pattern para state management
3. **Next.js**: MVC con Server Components y App Router

## 2. MVC en Backend Express.js

### 2.1 Estructura del Directorio Backend

```
backend/
├── src/
│   ├── controllers/        # Controllers (C en MVC)
│   ├── middleware/         # Middleware adicional
│   ├── routes/            # Rutas HTTP
│   ├── services/          # Services (Lógica de negocio)
│   ├── queues/            # Colas de trabajos
│   └── workers/           # Background workers
├── migrations/            # Migraciones de base de datos (M)
└── server.js             # Punto de entrada
```

### 2.2 Componentes MVC del Backend

#### **Models (M) - Supabase + Migraciones SQL**

Los modelos están definidos en la base de datos PostgreSQL a través de Supabase, con migraciones SQL:

**Estructura de Modelos Principales:**

```sql
-- Model: profiles
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    nombre_completo TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    telefono TEXT,
    rol user_role DEFAULT 'cliente'::user_role,
    tipo_membresia TEXT DEFAULT 'Regular Member',
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Model: vehiculos_cliente
CREATE TABLE public.vehiculos_cliente (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cliente_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    modelo_id INT REFERENCES public.modelos_vehiculo(id) ON DELETE RESTRICT NOT NULL,
    anio INT NOT NULL,
    vin TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Model: solicitudes_repuesto
CREATE TABLE public.solicitudes_repuesto (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cliente_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    vehiculo_id UUID REFERENCES public.vehiculos_cliente(id) ON DELETE SET NULL,
    pieza_nombre TEXT NOT NULL,
    descripcion TEXT,
    foto_url TEXT,
    vin_busqueda TEXT,
    direccion_entrega_id UUID REFERENCES public.direcciones_entrega(id) ON DELETE SET NULL,
    estado solicitud_status DEFAULT 'en_proceso'::solicitud_status,
    es_urgente BOOLEAN DEFAULT FALSE,
    vistas_contador INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);
```

**Acceso a Modelos vía Supabase Service:**

```javascript
// src/services/supabase.js
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

module.exports = supabase;
```

#### **Views (V) - Respuestas JSON**

En una API REST, las "Views" son las respuestas JSON que se envían a los clientes:

```javascript
// Ejemplo de respuesta JSON desde Controller
res.status(201).json({
  success: true,
  data: {
    id: 'uuid-del-vehiculo',
    cliente_id: 'uuid-del-cliente',
    modelo_id: 1,
    vin: '1HGBH41JXMN109186',
    anio: 2020,
    created_at: '2026-07-03T02:00:00.000Z'
  },
  message: 'Vehículo creado correctamente'
});
```

#### **Controllers (C) - Controladores HTTP**

Los controladores manejan las peticiones HTTP y coordinan entre Models y Services:

```javascript
// src/controllers/vehiculoController.js
const supabase = require('../services/supabase');

const createVehiculo = async (req, res) => {
  try {
    const { marcaId, modeloId, vin, anio, patente } = req.body;
    const clienteId = req.user.id; // Viene del middleware de autenticación

    // Validación de datos
    if (!marcaId || !modeloId) {
      return res.status(400).json({
        success: false,
        errors: [
          { campo: 'marcaId', mensaje: 'marcaId es requerido' },
          { campo: 'modeloId', mensaje: 'modeloId es requerido' }
        ],
        mensaje: 'Datos de entrada inválidos'
      });
    }

    // Inserción en Model (Supabase)
    const { data: vehiculo, error } = await supabase
      .from('vehiculos_cliente')
      .insert({
        cliente_id: clienteId,
        modelo_id: modeloId,
        vin,
        anio: parseInt(anio),
        patente
      })
      .select(`
        *,
        modelos_vehiculo (
          id,
          nombre,
          marca_id,
          marcas_vehiculo (
            id,
            nombre
          )
        )
      `)
      .single();

    if (error) {
      return res.status(500).json({
        success: false,
        error: error.message
      });
    }

    // Response (View)
    res.status(201).json({
      success: true,
      data: vehiculo,
      message: 'Vehículo creado correctamente'
    });

  } catch (error) {
    console.error('Error creating vehicle:', error);
    res.status(500).json({
      success: false,
      error: 'Error interno del servidor'
    });
  }
};

module.exports = { createVehiculo };
```

#### **Services - Lógica de Negocio Adicional**

Los servicios encapsulan lógica de negocio compleja que no pertenece directamente a los controladores:

```javascript
// src/services/cotizacionService.js
const supabase = require('./supabase');

class CotizacionService {
  static async calcularComision(precioVenta) {
    return precioVenta * 0.05; // 5% de comisión
  }

  static async verificarDisponibilidad(almacenId, piezaNombre) {
    // Lógica de negocio para verificar disponibilidad
    const { data, error } = await supabase
      .from('inventario')
      .select('*')
      .eq('almacen_id', almacenId)
      .eq('pieza_nombre', piezaNombre)
      .gt('cantidad', 0)
      .single();

    return { disponible: !!data, error };
  }

  static async procesarCotizacion(cotizacionData) {
    // Proceso complejo de negocio
    const comision = await this.calcularComision(cotizacionData.precio_venta);
    
    const { data, error } = await supabase
      .from('cotizaciones')
      .insert({
        ...cotizacionData,
        comision_plataforma: comision
      })
      .select()
      .single();

    return { data, error };
  }
}

module.exports = CotizacionService;
```

#### **Routes - Definición de Endpoints**

Las rutas conectan las peticiones HTTP con los controladores:

```javascript
// src/routes/index.js
const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');
const vehiculoController = require('../controllers/vehiculoController');

// Vehiculo routes (protected)
router.get('/vehicles', auth, vehiculoController.getVehiculos);
router.post('/vehicles', auth, vehiculoController.createVehiculo);
router.put('/vehicles/:id', auth, vehiculoController.updateVehiculo);
router.delete('/vehicles/:id', auth, vehiculoController.deleteVehiculo);

module.exports = router;
```

#### **Middleware - Intercepción de Peticiones**

```javascript
// src/middleware/auth.js
const jwt = require('jsonwebtoken');

const auth = (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

const requireRole = (role) => {
  return (req, res, next) => {
    if (req.user.rol !== role) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
};

module.exports = { auth, requireRole };
```

### 2.3 Flujo de Datos MVC en Backend

```
Cliente HTTP Request
    ↓
Router (routes/index.js)
    ↓
Middleware (auth.js)
    ↓
Controller (vehiculoController.js)
    ↓
Service (cotizacionService.js) [opcional]
    ↓
Model (Supabase/PostgreSQL)
    ↓
Service (procesamiento)
    ↓
Controller (formateo de respuesta)
    ↓
JSON Response (View)
    ↓
Cliente
```

## 3. MVC en Flutter (Aplicación Móvil)

### 3.1 Adaptación MVC en Flutter

Flutter utiliza una adaptación del patrón MVC con **Provider Pattern** para el manejo de estado:

```
lib/
├── models/              # Models (M)
├── providers/           # Controllers/ViewModels (C)
├── services/           # Services y API (Lógica de negocio)
├── screens/            # Views (V)
└── widgets/            # Componentes UI reutilizables
```

### 3.2 Models (M) - Modelos de Datos

```dart
// lib/models/vehiculo.dart
class Vehiculo {
  final String id;
  final String clienteId;
  final int modeloId;
  final String? vin;
  final int anio;
  final String? patente;
  final DateTime createdAt;
  final ModeloVehiculo? modelo;

  Vehiculo({
    required this.id,
    required this.clienteId,
    required this.modeloId,
    this.vin,
    required this.anio,
    this.patente,
    required this.createdAt,
    this.modelo,
  });

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      id: json['id'],
      clienteId: json['cliente_id'],
      modeloId: json['modelo_id'],
      vin: json['vin'],
      anio: json['anio'],
      patente: json['patente'],
      createdAt: DateTime.parse(json['created_at']),
      modelo: json['modelos_vehiculo'] != null 
          ? ModeloVehiculo.fromJson(json['modelos_vehiculo'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'modelo_id': modeloId,
      'vin': vin,
      'anio': anio,
      'patente': patente,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

### 3.3 Views (V) - Screens y Widgets

```dart
// lib/screens/vehicles_page.dart
class VehiclesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mis Vehículos')),
      body: Consumer<VehiculoProvider>(
        builder: (context, vehiculoProvider, child) {
          if (vehiculoProvider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: vehiculoProvider.vehiculos.length,
            itemBuilder: (context, index) {
              final vehiculo = vehiculoProvider.vehiculos[index];
              return VehicleCard(vehiculo: vehiculo);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CreateVehiclePage()),
        ),
        child: Icon(Icons.add),
      ),
    );
  }
}
```

### 3.4 Controllers (C) - Providers

```dart
// lib/providers/vehiculo_provider.dart
import 'package:flutter/foundation.dart';
import '../models/vehiculo.dart';
import '../services/vehiculo_service.dart';

class VehiculoProvider extends ChangeNotifier {
  final VehiculoService _vehiculoService = VehiculoService();
  
  List<Vehiculo> _vehiculos = [];
  bool _isLoading = false;
  String? _error;

  List<Vehiculo> get vehiculos => _vehiculos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadVehiculos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _vehiculos = await _vehiculoService.getVehiculos();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createVehiculo(Map<String, dynamic> vehiculoData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newVehiculo = await _vehiculoService.createVehiculo(vehiculoData);
      _vehiculos.add(newVehiculo);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### 3.5 Services - Lógica de Negocio y API

```dart
// lib/services/vehiculo_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/vehiculo.dart';
import 'api_client.dart';

class VehiculoService {
  final String baseUrl = ApiClient.baseUrl;

  Future<List<Vehiculo>> getVehiculos() async {
    final token = await ApiClient.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/vehicles'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> vehiculosJson = data['data'] ?? [];
      return vehiculosJson.map((json) => Vehiculo.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load vehicles');
    }
  }

  Future<Vehiculo> createVehiculo(Map<String, dynamic> vehiculoData) async {
    final token = await ApiClient.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/vehicles'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(vehiculoData),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Vehiculo.fromJson(data['data']);
    } else {
      throw Exception('Failed to create vehicle');
    }
  }
}
```

### 3.6 Flujo de Datos MVC en Flutter

```
Usuario Interacción UI
    ↓
View (vehicles_page.dart)
    ↓
Provider (vehiculo_provider.dart) [Controller]
    ↓
Service (vehiculo_service.dart)
    ↓
API Client (api_client.dart)
    ↓
Backend API
    ↓
Service (procesamiento de respuesta)
    ↓
Model (vehiculo.dart - fromJson)
    ↓
Provider (actualización de estado)
    ↓
View (reconstrucción con nuevos datos)
    ↓
Usuario
```

## 4. MVC en Next.js (Panel de Administración)

### 4.1 Adaptación MVC en Next.js

Next.js implementa MVC con **App Router** y **Server Components**:

```
admin-panel/src/
├── app/                  # Views (V) - Server Components
├── components/           # Componentes UI reutilizables
├── lib/                  # Services y utilidades (C)
└── types/                # TypeScript Interfaces (M)
```

### 4.2 Models (M) - TypeScript Interfaces

```typescript
// src/types/index.ts
export interface User {
  id: string;
  email: string;
  nombre_completo: string;
  rol: 'admin' | 'cliente' | 'almacen';
  telefono?: string;
  created_at: string;
}

export interface Orden {
  id: string;
  cliente_id: string;
  almacen_id: string;
  estado: 'pendiente' | 'en_proceso' | 'completado' | 'cancelado';
  total: number;
  created_at: string;
  cliente?: User;
  almacen?: Almacen;
}

export interface Almacen {
  id: string;
  nombre_comercial: string;
  direccion_texto: string;
  latitude: number;
  longitude: number;
  verificado: boolean;
  estado_abierto: boolean;
}
```

### 4.3 Views (V) - Server Components

```typescript
// src/app/orders/page.tsx
import { getOrdenes } from '@/lib/api';
import { OrdenTable } from '@/components/OrdenTable';

export default async function OrdersPage() {
  const ordenes = await getOrdenes();

  return (
    <div className="container mx-auto py-8">
      <h1 className="text-3xl font-bold mb-6">Gestión de Órdenes</h1>
      <OrdenTable ordenes={ordenes} />
    </div>
  );
}
```

### 4.4 Controllers (C) - API Functions y Server Actions

```typescript
// src/lib/api.ts
import { supabase } from './supabase';

export async function getOrdenes(): Promise<Orden[]> {
  const { data, error } = await supabase
    .from('ordenes_compra')
    .select(`
      *,
      cliente:profiles!ordenes_compra_cliente_id_fkey (*),
      almacen:almacenes (*)
    `)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data as Orden[];
}

export async function updateOrdenEstado(
  ordenId: string, 
  estado: string
): Promise<Orden> {
  const { data, error } = await supabase
    .from('ordenes_compra')
    .update({ estado })
    .eq('id', ordenId)
    .select()
    .single();

  if (error) throw error;
  return data as Orden;
}
```

### 4.5 Services - Lógica de Negocio

```typescript
// src/lib/ordenService.ts
import { supabase } from './supabase';
import { Orden } from '@/types';

export class OrdenService {
  static async calcularTotal(ordenId: string): Promise<number> {
    // Lógica de negocio para calcular total
    const { data: cotizaciones } = await supabase
      .from('cotizaciones')
      .select('precio_venta')
      .eq('orden_id', ordenId);

    const total = cotizaciones?.reduce(
      (sum, cot) => sum + cot.precio_venta, 
      0
    ) || 0;

    return total;
  }

  static async validarEstadoTransicion(
    orden: Orden, 
    nuevoEstado: string
  ): Promise<boolean> {
    // Validación de reglas de negocio
    const transicionesValidas = {
      'pendiente': ['en_proceso', 'cancelado'],
      'en_proceso': ['completado', 'cancelado'],
      'completado': [],
      'cancelado': []
    };

    return transicionesValidas[orden.estado]?.includes(nuevoEstado) || false;
  }
}
```

### 4.6 Flujo de Datos MVC en Next.js

```
Usuario Navegación
    ↓
View (app/orders/page.tsx)
    ↓
API Function (lib/api.ts) [Controller]
    ↓
Service (lib/ordenService.ts) [Lógica de negocio]
    ↓
Supabase Client (Model)
    ↓
PostgreSQL Database
    ↓
Service (procesamiento)
    ↓
API Function (formateo)
    ↓
View (Server Component render)
    ↓
Usuario
```

## 5. Comparación de Implementaciones MVC

### 5.1 Backend Express.js
- **M**: Tablas PostgreSQL + Supabase Client
- **V**: Respuestas JSON
- **C**: Controllers + Routes
- **Separación**: Más estricta y tradicional

### 5.2 Flutter
- **M**: Dart classes con fromJson/toJson
- **V**: Widgets + Screens
- **C**: Providers + Services
- **Separación**: Adaptada con reactive programming

### 5.3 Next.js
- **M**: TypeScript interfaces
- **V**: Server Components + Client Components
- **C**: API functions + Server Actions
- **Separación**: Integrada con React Server Components

## 6. Ventajas de la Arquitectura MVC

### 6.1 Mantenibilidad
- Separación clara de responsabilidades
- Código más organizado y legible
- Facilita la identificación y corrección de errores

### 6.2 Escalabilidad
- Componentes independientes pueden escalarse
- Fácil adición de nuevas funcionalidades
- Reutilización de componentes

### 6.3 Testabilidad
- Testing unitario de models, controllers y services
- Mocking de dependencias más sencillo
- Pruebas de integración bien definidas

### 6.4 Colaboración
- Equipos pueden trabajar en paralelo en diferentes capas
- Especialización por dominio (frontend vs backend)
- Code reviews más enfocados

## 7. Patrones Adicionales Implementados

### 7.1 Repository Pattern
Encapsula la lógica de acceso a datos:

```javascript
// Ejemplo en backend
class VehiculoRepository {
  async findById(id) {
    return await supabase.from('vehiculos_cliente').select('*').eq('id', id).single();
  }
  
  async findByCliente(clienteId) {
    return await supabase.from('vehiculos_cliente').select('*').eq('cliente_id', clienteId);
  }
}
```

### 7.2 Dependency Injection
Inyección de dependencias para facilitar testing:

```dart
// Ejemplo en Flutter
class VehiculoProvider {
  final VehiculoService _vehiculoService;
  
  VehiculoProvider({VehiculoService? vehiculoService})
      : _vehiculoService = vehiculoService ?? VehiculoService();
}
```

### 7.3 Factory Pattern
Creación de objetos complejos:

```typescript
// Ejemplo en Next.js
class OrdenFactory {
  static crearOrden(clienteId: string, almacenId: string): Orden {
    return {
      id: crypto.randomUUID(),
      cliente_id: clienteId,
      almacen_id: almacenId,
      estado: 'pendiente',
      total: 0,
      created_at: new Date().toISOString()
    };
  }
}
```

## 8. Mejores Prácticas MVC en RepuestosYa

### 8.1 Backend
- Controllers delgados: solo coordinan, no tienen lógica de negocio
- Services reutilizables: lógica de negocio compartida
- Validación en ambos niveles: controller y service
- Manejo de errores consistente

### 8.2 Flutter
- Providers para estado global, StatefulWidget para estado local
- Separación entre UI y lógica de negocio
- Services inmutables cuando sea posible
- Testing de providers y services

### 8.3 Next.js
- Server Components para contenido estático
- Client Components para interactividad
- API functions para llamadas a backend
- TypeScript para type safety

## 9. Consideraciones para Desarrolladores y Agentes AI

### 9.1 Para Desarrolladores Nuevos
- Entender el flujo de datos en cada componente
- Respetar la separación de responsabilidades
- Seguir los patrones existentes
- Documentar cambios en la arquitectura

### 9.2 Para Agentes AI
- Identificar el componente correcto para cada cambio
- Seguir las convenciones de nomenclatura
- Mantener consistencia en la implementación
- Validar impacto en otros componentes

### 9.3 Mantenimiento
- Revisar regularmente la consistencia MVC
- Refactor cuando las responsabilidades se mezclen
- Actualizar documentación cuando cambie la arquitectura
- Considerar implications de performance en cada capa