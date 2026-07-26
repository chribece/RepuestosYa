const { Worker } = require('bullmq');
const Redis = require('ioredis');

const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

const connection = new Redis(redisUrl, {
  maxRetriesPerRequest: null
});

const worker = new Worker(
  'notificaciones',
  async (job) => {
    const { name } = job;

    console.log(`[Worker] Procesando job tipo: ${name}`);

    switch (name) {
      case 'cotizacion-creada':
        {
          const { cotizacionId, solicitudId } = job.data;
          console.log(`[Worker] Notificación: Cotización creada - ID: ${cotizacionId}, Solicitud: ${solicitudId}`);
          // TODO: Integrar con SendGrid/FCM - Enviar notificación al cliente sobre nueva cotización
          await new Promise(resolve => setTimeout(resolve, 1500));
          console.log(`[Worker] Notificación enviada: cotización ${cotizacionId} creada`);
        }
        break;

      case 'notificar-almacen-ganador':
        {
          const { cotizacionId, almacenId, solicitudId, ordenId } = job.data;
          console.log(`[Worker] Notificación: Almacén ganador - Almacén: ${almacenId}, Cotización: ${cotizacionId}, Orden: ${ordenId}`);
          // TODO: Integrar con SendGrid/FCM - Enviar notificación al almacén que ganó la cotización
          await new Promise(resolve => setTimeout(resolve, 1500));
          console.log(`[Worker] Notificación enviada: almacén ${almacenId} ganó la cotización ${cotizacionId}`);
        }
        break;

      case 'notificar-almacenes-perdedores':
        {
          const { solicitudId, cotizacionGanadoraId } = job.data;
          console.log(`[Worker] Notificación: Almacenes perdedores - Solicitud: ${solicitudId}, Cotización ganadora: ${cotizacionGanadoraId}`);
          // TODO: Integrar con SendGrid/FCM - Enviar notificación a los almacenes que perdieron la cotización
          await new Promise(resolve => setTimeout(resolve, 1500));
          console.log(`[Worker] Notificación enviada: almacenes perdedores de solicitud ${solicitudId}`);
        }
        break;

      case 'notificar-cliente-aceptacion':
        {
          const { cotizacionId, clienteId, ordenId } = job.data;
          console.log(`[Worker] Notificación: Cliente aceptación - Cliente: ${clienteId}, Cotización: ${cotizacionId}, Orden: ${ordenId}`);
          // TODO: Integrar con SendGrid/FCM - Enviar notificación al cliente sobre la aceptación de su cotización
          await new Promise(resolve => setTimeout(resolve, 1500));
          console.log(`[Worker] Notificación enviada: cliente ${clienteId} aceptó cotización ${cotizacionId}`);
        }
        break;

      case 'notificar-almacen-rechazo':
        {
          const { cotizacionId, almacenId, solicitudId } = job.data;
          console.log(`[Worker] Notificación: Almacén rechazo - Almacén: ${almacenId}, Cotización: ${cotizacionId}, Solicitud: ${solicitudId}`);
          // TODO: Integrar con SendGrid/FCM - Enviar notificación al almacén sobre el rechazo de su cotización
          await new Promise(resolve => setTimeout(resolve, 1500));
          console.log(`[Worker] Notificación enviada: almacén ${almacenId} rechazado en cotización ${cotizacionId}`);
        }
        break;

      default:
        console.log(`[Worker] Tipo de job no reconocido: ${name}`);
    }
  },
  {
    connection,
    concurrency: 5
  }
);

worker.on('completed', (job) => {
  console.log(`[Worker] Job ${job.id} (${job.name}) completado exitosamente`);
});

worker.on('failed', (job, err) => {
  console.error(`[Worker] Job ${job?.id} (${job?.name}) falló:`, err.message);
});

console.log('[Worker] Worker de notificaciones iniciado');
