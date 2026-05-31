module.exports = {
  darkMode: 'class',
  content: ['./src/index.html'],
  safelist: [
    'bg-emerald-600/90',
    'bg-rose-600/90',
    'bg-emerald-600',
    'hover:bg-emerald-700',
    'bg-rose-600',
    'hover:bg-rose-700',
    'bg-rose-100',
    'hover:bg-rose-200',
    'text-rose-700',
    'text-emerald-600',
    'dark:text-emerald-400',
    'font-sans',
    'font-serif',
    'font-mono'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        mono: [
          'ui-monospace',
          'SFMono-Regular',
          'Menlo',
          'Monaco',
          'Consolas',
          'Liberation Mono',
          'Courier New',
          'monospace'
        ],
        signature: ['Great Vibes', 'cursive']
      },
      colors: {
        brand: {
          50: '#f0f9ff',
          100: '#e0f2fe',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
          900: '#0c4a6e'
        }
      }
    }
  }
};
