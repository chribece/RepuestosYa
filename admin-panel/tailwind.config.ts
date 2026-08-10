import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: '#FF5722',
        secondary: '#1E95F2',
        dark: '#131313',
        surface: '#1E1E1E',
        surfaceHigh: '#2A2A2A',
      },
    },
  },
  plugins: [],
};
export default config;
