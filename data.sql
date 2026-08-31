-- Forzar el esquema activo a 'public'
SET search_path TO public;

-- 4. INSERCIÓN DE DATOS

-- Categorías
INSERT INTO public.categoria (nombre, descripcion) VALUES 
('Pizzas', 'Pizzas artesanales al horno de piedra'),
('Empanadas', 'Empanadas criollas horneadas y fritas'),
('Bebidas', 'Gaseosas y aguas saborizadas');

-- Productos
INSERT INTO public.producto (nombre, precio, descripcion, stock, disponible, categoria_id) VALUES 
('Fugazzeta', 1800.00, 'Pizza de cebolla y queso', 10, TRUE, 1),
('Muzza Grande', 2200.00, 'Pizza clásica de mozzarella', 15, TRUE, 1),
('Empanada Carne Suave', 500.00, 'Carne cortada a cuchillo', 50, TRUE, 2),
('Coca Cola 1.5L', 1200.00, 'Bebida descremada o común', 20, TRUE, 3);

-- Usuarios
INSERT INTO public.usuario (nombre, apellido, mail, celular, contrasena, rol) VALUES 
('Ana', 'Garis', 'ana@x.com', '2611234567', 'hash123', 'USUARIO'),
('Carlos', 'Admin', 'admin@store.com', '2619876543', 'hash456', 'ADMIN');

-- Pedidos
INSERT INTO public.pedido (usuario_id, forma_pago, estado, total) VALUES 
(1, 'EFECTIVO', 'CONFIRMADO', 4200.00),
(1, 'TARJETA', 'PENDIENTE', 3000.00);

-- Detalle de los pedidos
INSERT INTO public.detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal) VALUES 
(1, 1, 1, 1800.00, 1800.00),
(1, 4, 2, 1200.00, 2400.00),
(2, 3, 6, 500.00, 3000.00);