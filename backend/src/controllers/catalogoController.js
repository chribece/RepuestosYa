const supabase = require('../services/supabase');

/**
 * GET /api/catalog/part-categories
 * Obtener todas las categorías de repuestos activas.
 */
const getCategorias = async (req, res) => {
  try {
    const { data: categorias, error } = await supabase
      .from('categorias_repuestos')
      .select('id, nombre, slug, descripcion')
      .eq('activo', true)
      .order('nombre', { ascending: true });

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    res.json(categorias || []);
  } catch (error) {
    console.error('Get categorias error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

/**
 * GET /api/catalog/parts
 * Obtener repuestos del catálogo, opcionalmente filtrados por categoría o búsqueda.
 * Query params: category_id, q
 */
const getRepuestos = async (req, res) => {
  try {
    const { category_id, q } = req.query;

    let query = supabase
      .from('repuestos_catalogo')
      .select('id, categoria_id, nombre, slug, sinonimos')
      .eq('activo', true);

    if (category_id) {
      query = query.eq('categoria_id', category_id);
    }

    if (q) {
      // Búsqueda simple por nombre o en el array de sinónimos
      // PostgreSQL: nombre ILIKE %q% OR sinonimos @> ARRAY[q]
      // Con Supabase JS client, para búsquedas complejas en arrays a veces es mejor or()
      query = query.or(`nombre.ilike.%${q}%,sinonimos.cs.{${q}}`);
    }

    const { data: repuestos, error } = await query.order('nombre', { ascending: true });

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    res.json(repuestos || []);
  } catch (error) {
    console.error('Get repuestos error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
};

module.exports = {
  getCategorias,
  getRepuestos
};
