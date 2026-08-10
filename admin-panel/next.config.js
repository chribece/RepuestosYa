/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'vpgnasrlgdgkxpggorxl.supabase.co',
      },
    ],
  },
};
module.exports = nextConfig;
