const supabase = require('../services/supabase');
const multer = require('multer');

// Configurar multer para almacenar en memoria (para subir directamente a Supabase)
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // Límite 10 MB
  fileFilter: (req, file, cb) => {
    // Aceptar solo imágenes
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Solo se permiten imágenes'), false);
    }
  }
});

// Middleware para manejar la subida de un solo archivo (campo 'file')
const uploadMiddleware = upload.single('file');

// Controlador principal
const uploadFile = async (req, res) => {
  try {
    // Verificar si hay archivo
    if (!req.file) {
      return res.status(400).json({ error: 'No se envió ningún archivo' });
    }

    const file = req.file;
    const folder = req.body.folder || 'general';
    // Generar nombre único con timestamp y limpiar espacios
    const fileName = `${folder}/${Date.now()}_${file.originalname.replace(/\s/g, '_')}`;

    console.log(`Subiendo archivo: ${fileName}, tamaño: ${file.size} bytes`);

    // Subir a Supabase Storage (bucket 'Repuestosya')
    const { data, error } = await supabase.storage
      .from('Repuestosya')
      .upload(fileName, file.buffer, {
        contentType: file.mimetype,
        cacheControl: '3600',
        upsert: false,
      });

    if (error) {
      console.error('Error subiendo a Storage:', error);
      return res.status(500).json({ error: error.message });
    }

    // Obtener la URL pública del archivo
    const publicUrl = supabase.storage.from('Repuestosya').getPublicUrl(fileName);

    // Respuesta exitosa
    res.status(200).json({ 
      url: publicUrl,
      fileName: fileName,
      message: 'Archivo subido exitosamente' 
    });
  } catch (error) {
    console.error('Error en uploadFile:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  uploadMiddleware,
  uploadFile
};