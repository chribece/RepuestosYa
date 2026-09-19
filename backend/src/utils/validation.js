/**
 * Helpers de validación compartidos por los controladores.
 *
 * - validationError / validationErrors: normalización 422 del contrato
 *   (`{ message: 'Errores de validación', errors: [{ field, message }] }`),
 *   mismo formato que usaba solicitudController.
 * - validateImageUrl: valida que una URL de foto pertenezca al Storage del
 *   proyecto (SUPABASE_URL) y que el objeto exista con Content-Type `image/*`
 *   y tamaño <= 10 MB (mismo criterio del antiguo uploadController.js:
 *   filtro `image/*` y límite 10 MB).
 */

const MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB
const HEAD_TIMEOUT_MS = 5000;

const validationError = (field, message) => ({
  message: 'Errores de validación',
  errors: [{ field, message }]
});

const validationErrors = (errors) => ({
  message: 'Errores de validación',
  errors
});

/**
 * Valida la URL de una foto subida al Storage del proyecto.
 * La foto opcional: si `url` está vacío se acepta sin imagen.
 *
 * @param {string|null|undefined} url URL pública devuelta por Supabase Storage
 * @returns {Promise<{valid: boolean, value?: string|null, message?: string}>}
 */
async function validateImageUrl(url) {
  if (url === undefined || url === null || url === '') {
    return { valid: true, value: null };
  }

  let parsed;
  try {
    parsed = new URL(url);
  } catch (_) {
    return { valid: false, message: 'La URL de la imagen no es válida.' };
  }

  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
    return { valid: false, message: 'La URL de la imagen debe ser http(s).' };
  }

  let projectHost = null;
  try {
    projectHost = new URL(process.env.SUPABASE_URL).host;
  } catch (_) {
    // SUPABASE_URL ausente o inválido: no se puede verificar, fail-closed.
  }

  if (!projectHost) {
    return { valid: false, message: 'No se pudo validar la URL de la imagen.' };
  }

  if (parsed.host !== projectHost) {
    return {
      valid: false,
      message: 'La URL de la imagen debe pertenecer al almacenamiento del proyecto.'
    };
  }

  // Verificación HEAD: confirma que el objeto existe, es una imagen y no
  // supera el límite de 10 MB. Un HEAD que falle rechaza con 422.
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), HEAD_TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      method: 'HEAD',
      redirect: 'follow',
      signal: controller.signal
    });

    if (!response.ok) {
      return { valid: false, message: 'La imagen no está disponible en este momento.' };
    }

    const contentType = response.headers.get('content-type') || '';
    if (!contentType.startsWith('image/')) {
      return { valid: false, message: 'El archivo referenciado no es una imagen.' };
    }

    const contentLength = Number(response.headers.get('content-length') || 0);
    if (contentLength > MAX_IMAGE_SIZE_BYTES) {
      return {
        valid: false,
        message: 'La imagen supera el tamaño máximo permitido (10 MB).'
      };
    }
  } catch (_) {
    return { valid: false, message: 'No se pudo verificar la imagen. Intenta nuevamente.' };
  } finally {
    clearTimeout(timer);
  }

  return { valid: true, value: url };
}

module.exports = {
  validationError,
  validationErrors,
  validateImageUrl,
  MAX_IMAGE_SIZE_BYTES
};
