Actúa como un experto en flutter y supabase
Analiza la tabla profiles
Necesito implementar una lógica post-login que:
1.	Obtenga el id del usuario autenticado actual
2.	Realice una consulta a la tabla profiles para obtener el campo role
3.	Guarde este rol en un estado global (o Provider/Riverpod) para que la aplicación sea consiente de si el usuario es admin o almacen asegúrate de manejar errores si el perfil no existe
4.	Si el usuario es role: cliente debe navegar a la página home_page.dart
si el usuario es role: almacen debe navegar a la página  warehouse_dashboard.dart
