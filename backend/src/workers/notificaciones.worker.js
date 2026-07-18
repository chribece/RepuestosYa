const { Worker } = require('bullmq');
const Redis = require('ioredis');

const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

const connection = new Redis(redisUrl, {
  maxRetriesPerRequest: null
});

const worker = new Worker(
  'notificaciones',
  async (job) => {
    const { cotizacionId, solicitudId } = job.data;

    console.log(`[Worker] Procesando notificación para cotización ${cotizacionId}, solicitud ${solicitudId}`);

    // Simular envío de notificación (delay de 1500ms)
    await new Promise(resolve => setTimeout(resolve, 1500));

    // TODO: Aquí iría el envío real de notificación:
    // - Email al cliente sobre nueva cotización
    // - Push notification via FCM
    // - SMS si está configurado
    console.log(`[Worker] Notificación enviada para cotización ${cotizacionId}`);
  },
  {
    connection,
    concurrency: 5
  }
);

worker.on('completed', (job) => {
  console.log(`[Worker] Job ${job.id} completado exitosamente`);
});

worker.on('failed', (job, err) => {
  console.error(`[Worker] Job ${job?.id} falló:`, err.message);
});

console.log('[Worker] Worker de notificaciones iniciado');
