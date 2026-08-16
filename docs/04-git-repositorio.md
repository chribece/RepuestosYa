# Detalle Técnico del Uso de Git y Repositorio - RepuestosYa

## 1. Configuración del Repositorio

### 1.1 Información del Repositorio

- **Repositorio**: RepuestosYa
- **URL**: https://github.com/chribece/RepuestosYa.git
- **Remote**: `origin`
- **Plataforma**: GitHub
- **Tipo**: Repositorio público

### 1.2 Estructura de Ramas

```
main (principal)
  ├── development (desarrollo)
  ├── feature/* (ramas de funcionalidades)
  ├── bugfix/* (ramas de correcciones)
  └── hotfix/* (ramas de emergencia)
```

### 1.3 Rama Principal

- **Rama principal**: `main`
- **Rama de desarrollo**: `development` (si existe)
- **Estrategia**: Git Flow simplificado

## 2. Flujo de Trabajo Git (Workflow)

### 2.1 Estrategia de Branching

RepuestosYa utiliza una estrategia de branching simplificada adaptada a las necesidades del proyecto:

```
main (producción)
    ↑
    │ merge
    │
development (desarrollo activo)
    ↑
    │ merge
    │
feature/nueva-funcionalidad
bugfix/correccion-error
hotfix/emergencia-produccion
```

### 2.2 Tipos de Ramas

#### **Rama Main**
- Propósito: Código de producción estable
- Protección: Requiere pull request para merge
- Deployments: Automáticos a producción

#### **Rama Development**
- Propósito: Integración de funcionalidades
- Estabilidad: Código relativamente estable
- Testing: Integración continua

#### **Feature Branches**
- Propósito: Desarrollo de nuevas funcionalidades
- Nomenclatura: `feature/nombre-funcionalidad`
- Ciclo de vida: Creada desde development, mergeada a development

#### **Bugfix Branches**
- Propósito: Corrección de bugs
- Nomenclatura: `bugfix/descripcion-correccion`
- Ciclo de vida: Creada desde development/main, mergeada según severidad

#### **Hotfix Branches**
- Propósito: Correcciones urgentes en producción
- Nomenclatura: `hotfix/descripcion-emergencia`
- Ciclo de vida: Creada desde main, mergeada a main y development

### 2.3 Flujo de Trabajo Estándar

```bash
# 1. Actualizar rama principal
git checkout main
git pull origin main

# 2. Crear rama de funcionalidad
git checkout -b feature/nueva-funcionalidad

# 3. Realizar cambios y commits
git add .
git commit -m "feat: descripción de la funcionalidad"

# 4. Push al repositorio remoto
git push origin feature/nueva-funcionalidad

# 5. Crear Pull Request en GitHub
# 6. Revisión y aprobación
# 7. Merge a development/main
# 8. Eliminar rama local y remota
git branch -d feature/nueva-funcionalidad
git push origin --delete feature/nueva-funcionalidad
```

## 3. Convenciones de Commits

### 3.1 Formato de Mensajes de Commit

RepuestosYa sigue el formato **Conventional Commits**:

```
<tipo>(<alcance>): <descripción>

[opcional: cuerpo]

[opcional: pie de página]
```

### 3.2 Tipos de Commits

- **feat**: Nueva funcionalidad
- **fix**: Corrección de bug
- **docs**: Cambios en documentación
- **style**: Cambios de formato (espacios, sangría)
- **refactor**: Refactorización de código
- **perf**: Mejoras de performance
- **test**: Adición o modificación de tests
- **chore**: Cambios en herramientas de build, configuración
- **ci**: Cambios en configuración de CI/CD

### 3.3 Ejemplos de Commits Recientes

```bash
feat: implementar panel de administración web (Next.js) y reconfiguración de puertos
Correccion bug orden de compra pantalla de inicio
implementar notificaciones realtime
feat: implementar subida y visualización de imágenes en Supabase Storage
feat(almacen): implementar gestión de órdenes y filtros en dashboard
feat: implementar flujo completo de órdenes de compra
perf(auth): optimizar consultas en login y eliminar redundancias
refactor(queries): implementar estrategia Eager/Lazy loading en solicitudes
feat(bullmq): implementar cola de notificaciones asíncronas con BullMQ
feat(cache): validado - mejora de 4000ms a 10ms (382x más rápido)
```

### 3.4 Patrones de Commits por Componente

#### **Backend**
```bash
feat(api): agregar endpoint para gestión de almacenes
fix(auth): corregir validación de tokens expirados
perf(database): optimizar consulta de solicitudes activas
```

#### **Flutter**
```bash
feat(mobile): implementar pantalla de solicitudes
fix(ui): corregir error en渲染 de lista de vehículos
refactor(provider): optimizar estado de usuario
```

#### **Admin Panel**
```bash
feat(admin): agregar dashboard de métricas
fix(routing): corregir navegación en órdenes
style(admin): actualizar estilos de tabla
```

## 4. Configuración de .gitignore

### 4.1 Archivos Ignorados por Componente

#### **General**
```gitignore
# Archivos del sistema
.DS_Store
Thumbs.db

# Archivos de editor
.vscode/
.idea/
*.swp
*.swo
```

#### **Flutter**
```gitignore
.dart_tool/
.flutter-plugins-dependencies
.pub-cache/
.pub/
/build/
/android/app/debug
/android/app/profile
/android/app/release
```

#### **Backend**
```gitignore
backend/node_modules/
backend/.env
npm-debug.log*
```

#### **Admin Panel**
```gitignore
admin-panel/node_modules/
admin-panel/.next/
admin-panel/.env.local
```

### 4.2 Variables de Entorno

**ARCHIVOS NUNCA COMMITADOS:**
- `.env`
- `.env.local`
- `.env.development.local`
- `.env.test.local`
- `.env.production.local`

**ARCHIVOS DE EJEMPLO (COMMITADOS):**
- `.env.example` (plantilla para desarrolladores)

## 5. Gestión de Conflictos

### 5.1 Prevención de Conflictos

```bash
# Antes de empezar a trabajar
git checkout main
git pull origin main

# Crear rama desde main actualizado
git checkout -b feature/nueva-funcionalidad

# Trabajo regular con sincronización
git fetch origin
git rebase origin/main
```

### 5.2 Resolución de Conflictos

```bash
# Durante merge o rebase
git status
# Editar archivos con conflictos
git add <archivos-resueltos>
git rebase --continue
# o
git commit
```

### 5.3 Estrategias de Merge

#### **Merge**
```bash
git checkout main
git merge feature/nueva-funcionalidad
```
- Crea un commit de merge
- Preserva historia completa
- Útil para features importantes

#### **Rebase**
```bash
git checkout feature/nueva-funcionalidad
git rebase main
```
- Historia lineal
- Reescribe commits
- Útil para features pequeñas

#### **Squash**
```bash
git checkout main
git merge --squash feature/nueva-funcionalidad
git commit -m "feat: descripción consolidada"
```
- Un solo commit consolidado
- Historia limpia
- Útil para PRs con muchos commits pequeños

## 6. Pull Requests y Code Review

### 6.1 Plantilla de Pull Request

```markdown
## Descripción
Breve descricripción de los cambios implementados.

## Tipo de Cambio
- [ ] Bug fix (corrección de error que rompe funcionalidad)
- [ ] New feature (funcionalidad nueva que no rompe nada)
- [ ] Breaking change (cambio que rompe funcionalidad existente)
- [ ] Documentation update (actualización de documentación)

## Contexto y Motivación
Explicación de por qué se necesita este cambio.

## Cambios Realizados
- Lista de cambios principales
- Archivos modificados
- Nuevas funcionalidades

## Testing
- [ ] Tests unitarios actualizados
- [ ] Tests de integración actualizados
- [ ] Manual testing realizado
- [ ] Screenshots (si aplica)

## Checklist
- [ ] Mi código sigue las guías de estilo del proyecto
- [ ] He realizado auto-revisión de mi código
- [ ] He comentado código complejo
- [ ] He actualizado la documentación
- [ ] No hay nuevos warnings
- [ ] He agregado tests que prueban mis cambios
- [ ] Todos los tests pasan
```

### 6.2 Proceso de Code Review

1. **Automático**: CI/CD ejecuta tests y linters
2. **Revisión**: Al menos un desarrollador revisa el PR
3. **Aprobación**: Requerida antes del merge
4. **Correcciones**: Solicitadas si hay issues
5. **Merge**: Realizado por mantenedor o automáticamente

## 7. Integración Continua (CI/CD)

### 7.1 Configuración de GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main, development ]
  pull_request:
    branches: [ main, development ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '18'
    
    - name: Install Backend Dependencies
      run: |
        cd backend
        npm ci
    
    - name: Run Backend Tests
      run: |
        cd backend
        npm test
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.12.1'
    
    - name: Install Flutter Dependencies
      run: flutter pub get
    
    - name: Run Flutter Tests
      run: flutter test
```

### 7.2 Triggers de CI/CD

- **Push a main**: Ejecuta tests completos
- **Push a development**: Ejecuta tests básicos
- **Pull Request**: Ejecuta tests y linting
- **Merge a main**: Despliegue automático

## 8. Gestión de Releases

### 8.1 Versionado Semántico

RepuestosYa sigue **Semantic Versioning** (SemVer):

```
MAJOR.MINOR.PATCH

MAJOR: Cambios incompatibles con la API anterior
MINOR: Funcionalidades nuevas compatibles con versiones anteriores
PATCH: Correcciones de bugs compatibles con versiones anteriores
```

### 8.2 Ejemplos de Versiones

- `1.0.0` - Versión inicial estable
- `1.1.0` - Nueva funcionalidad (panel de administración)
- `1.1.1` - Corrección de bug en órdenes de compra
- `2.0.0` - Cambio mayor en arquitectura

### 8.3 Proceso de Release

```bash
# 1. Crear rama de release
git checkout -b release/v1.1.0

# 2. Actualizar versiones en archivos
# - pubspec.yaml
# - package.json (backend)
# - package.json (admin-panel)

# 3. Commit de versión
git commit -m "chore: bump version to 1.1.0"

# 4. Merge a main
git checkout main
git merge release/v1.1.0

# 5. Crear tag en GitHub
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin v1.1.0

# 6. Merge a development
git checkout development
git merge main
```

## 9. Gestión de Issues

### 9.1 Tipos de Issues

- **Bug**: Error en el código
- **Feature**: Solicitud de nueva funcionalidad
- **Improvement**: Mejora existente
- **Documentation**: Actualización de documentación
- **Task**: Tarea de desarrollo

### 9.2 Prioridades

- **Critical**: Bloquea producción
- **High**: Importante pero no bloqueante
- **Medium**: Normal
- **Low**: Mejora opcional

### 9.3 Ciclo de Vida de Issue

```
Open → In Progress → Review → Testing → Done → Closed
                ↓
              Blocked
```

## 10. Buenas Prácticas

### 10.1 Commits

- **Commits atómicos**: Un cambio lógico por commit
- **Mensajes claros**: Descriptivos y concisos
- **Frecuentes**: Commits pequeños y frecuentes
- **Testing**: Tests que acompañan cambios

### 10.2 Branches

- **Ciclo de vida corto**: Branches efímeras
- **Nombres descriptivos**: Claros y específicos
- **Sincronización**: Regular con main/development
- **Limpieza**: Eliminar branches después del merge

### 10.3 Colaboración

- **Code reviews**: Revisión obligatoria
- **Comunicación**: Discusión de cambios importantes
- **Documentación**: Actualizar docs con cambios
- **Testing**: Tests para nuevas funcionalidades

## 11. Comandos Útiles

### 11.1 Comandos Diarios

```bash
# Estado del repositorio
git status

# Historial de commits
git log --oneline --graph --all

# Ramas
git branch -a
git branch -v

# Stashing
git stash
git stash pop

# Limpiar
git clean -fd
```

### 11.2 Comandos de Emergencia

```bash
# Deshacer último commit (mantener cambios)
git reset --soft HEAD~1

# Deshacer último commit (descartar cambios)
git reset --hard HEAD~1

# Recuperar archivo borrado
git checkout HEAD~1 -- path/to/file

# Revertir commit específico
git revert <commit-hash>
```

### 11.3 Comandos de Limpieza

```bash
# Limpiar branches locales eliminados
git remote prune origin

# Limpiar branches merged
git branch --merged | grep -v "main" | xargs git branch -d

# Limpiar tags remotos
git tag -d <tag-name>
git push origin :refs/tags/<tag-name>
```

## 12. Seguridad

### 12.1 Protección de Ramas

**Configuración de GitHub:**
- **Rama main**: 
  - Require pull request before merge
  - Require status checks to pass
  - Require branches to be up to date
  - Restrict who can push

### 12.2 Secrets Management

**Nunca commitar:**
- Contraseñas
- API keys
- Tokens de autenticación
- Certificados

**Usar GitHub Secrets:**
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `JWT_SECRET`
- etc.

### 12.3 Commits Firmados

```bash
# Configurar firma de commits
git config --global commit.gpgsign true

# Verificar firma
git log --show-signature
```

## 13. Monitoreo y Métricas

### 13.1 Métricas de Repositorio

- **Frecuencia de commits**: Actividad del equipo
- **Tamaño de PRs**: Complejidad de cambios
- **Tiempo de review**: Eficiencia del proceso
- **Tiempo de merge**: Velocidad de integración

### 13.2 GitHub Insights

- **Contributors**: Actividad por colaborador
- **Commit activity**: Gráfico de commits
- **Pulse**: Resumen de actividad
- **Traffic**: Visitas y clones

## 14. Troubleshooting

### 14.1 Problemas Comunes

#### **Merge Conflicts**
```bash
# Identificar conflictos
git status

# Resolver conflictos manualmente
# Editar archivos marcados con <<<<<<< HEAD

# Marcar como resueltos
git add <archivo>
git commit
```

#### **Detached HEAD**
```bash
# Volver a una rama
git checkout main

# O crear nueva rama desde el estado actual
git checkout -b nueva-rama
```

#### **Push Rechazado**
```bash
# Pull con rebase
git pull --rebase origin main

# O force push (con cuidado)
git push --force-with-lease origin feature-branch
```

### 14.2 Recuperación de Datos

```bash
# Encontrar commit perdido
git reflog

# Recuperar estado anterior
git checkout <hash-del-commit>

# Crear rama desde estado recuperado
git checkout -b recuperado <hash-del-commit>
```

## 15. Integración con Herramientas

### 15.1 IDE Integration

**VS Code:**
- GitLens: Visualización de blame y cambios
- Git Graph: Visualización de branches
- GitHub Copilot: Asistencia con código

**Android Studio:**
- Git integration nativa
- Visualización de cambios
- Merge tool integrado

### 15.2 Herramientas de Línea de Comando

**GitHub CLI:**
```bash
gh pr list
gh pr create
gh pr merge
gh issue list
```

**Git Extras:**
```bash
git summary
git effort
git churn
```

## 16. Documentación de Cambios

### 16.1 Changelog

Mantener un `CHANGELOG.md` con:

```markdown
# Changelog

## [1.1.0] - 2026-08-14
### Added
- Panel de administración web con Next.js
- Sistema de notificaciones en tiempo real
- Gestión de imágenes en Supabase Storage

### Fixed
- Bug en orden de compra en pantalla de inicio
- Optimización de consultas de autenticación

### Performance
- Mejora de 4000ms a 10ms en caché (382x más rápido)
- Implementación de estrategia Eager/Lazy loading
```

### 16.2 Documentación Técnica

- Actualizar `/docs/` con cambios arquitectónicos
- Documentar nuevos endpoints en `API_DOCUMENTATION.md`
- Actualizar diagramas de base de datos si es necesario

## 17. Consideraciones para Desarrolladores y Agentes AI

### 17.1 Para Desarrolladores Nuevos

1. **Configurar entorno local**
   ```bash
   git clone https://github.com/chribece/RepuestosYa.git
   cd RepuestosYa
   ```

2. **Configurar upstream**
   ```bash
   git remote add upstream https://github.com/chribece/RepuestosYa.git
   ```

3. **Crear rama de trabajo**
   ```bash
   git checkout -b feature/mi-funcionalidad
   ```

4. **Seguir convenciones de commits**
   - Usar formato conventional commits
   - Commits atómicos y descriptivos
   - Incluir tests cuando sea posible

### 17.2 Para Agentes AI

1. **Leer commits recientes** para entender el estilo
2. **Seguir estructura de directorios** existente
3. **Respetar .gitignore** no agregar archivos ignorados
4. **Usar comandos git seguros** (evitar force push sin confirmación)
5. **Documentar cambios** en archivos apropiados

### 17.3 Mantenimiento del Repositorio

- **Limpieza regular** de branches merged
- **Actualización de .gitignore** cuando sea necesario
- **Revisión de seguridad** de secrets y tokens
- **Optimización del repositorio** (git gc)
- **Documentación actualizada** de procesos

## 18. Recursos Adicionales

### 18.1 Documentación Oficial

- **Git Documentation**: https://git-scm.com/doc
- **GitHub Guides**: https://guides.github.com/
- **Conventional Commits**: https://www.conventionalcommits.org/
- **Semantic Versioning**: https://semver.org/

### 18.2 Herramientas Recomendadas

- **GitKraken**: Cliente Git gráfico
- **SourceTree**: Cliente Git gratuito
- **GitHub Desktop**: Cliente oficial de GitHub
- **GitLens**: Extensión de VS Code para Git