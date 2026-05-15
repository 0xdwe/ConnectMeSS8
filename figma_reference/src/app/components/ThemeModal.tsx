import { X, Sun, Moon, Check } from 'lucide-react';
import { useTheme } from './ThemeContext';

interface ThemeModalProps {
  onClose: () => void;
}

export function ThemeModal({ onClose }: ThemeModalProps) {
  const { theme, setTheme } = useTheme();

  const themes = [
    {
      id: 'light',
      name: 'Light',
      icon: Sun,
      preview: {
        bg: '#ffffff',
        text: '#000000',
        accent: '#C5A8E8'
      }
    },
    {
      id: 'dark',
      name: 'Dark',
      icon: Moon,
      preview: {
        bg: '#1a1a1a',
        text: '#ffffff',
        accent: '#00b8b8'
      }
    }
  ];

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-md w-full p-6">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-xl font-semibold dark:text-white">Choose Theme</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full"
          >
            <X size={24} className="dark:text-white" />
          </button>
        </div>

        <div className="grid grid-cols-2 gap-4">
          {themes.map(themeOption => {
            const Icon = themeOption.icon;
            const isSelected = theme === themeOption.id;

            return (
              <button
                key={themeOption.id}
                onClick={() => {
                  setTheme(themeOption.id as 'light' | 'dark');
                  setTimeout(onClose, 300);
                }}
                className={`relative p-4 rounded-xl border-2 transition-all ${
                  isSelected
                    ? 'border-[#C5A8E8] bg-[#C5A8E8]/5 dark:bg-[#00b8b8]/10'
                    : 'border-gray-200 dark:border-gray-600 hover:border-gray-300 dark:hover:border-gray-500'
                }`}
              >
                {isSelected && (
                  <div
                    className="absolute top-2 right-2 w-6 h-6 rounded-full flex items-center justify-center text-white"
                    style={{ backgroundColor: '#C5A8E8' }}
                  >
                    <Check size={16} />
                  </div>
                )}

                <div className="flex flex-col items-center gap-3">
                  <Icon
                    size={40}
                    style={{ color: isSelected ? '#C5A8E8' : '#737877' }}
                  />
                  <span
                    className="font-medium"
                    style={{ color: isSelected ? '#C5A8E8' : '#737877' }}
                  >
                    {themeOption.name}
                  </span>

                  <div
                    className="w-full h-16 rounded-lg border border-gray-300 dark:border-gray-600 overflow-hidden"
                    style={{ backgroundColor: themeOption.preview.bg }}
                  >
                    <div className="h-4" style={{ backgroundColor: themeOption.preview.accent }} />
                    <div className="p-2">
                      <div
                        className="w-3/4 h-2 rounded mb-1"
                        style={{ backgroundColor: themeOption.preview.text, opacity: 0.2 }}
                      />
                      <div
                        className="w-1/2 h-2 rounded"
                        style={{ backgroundColor: themeOption.preview.text, opacity: 0.2 }}
                      />
                    </div>
                  </div>
                </div>
              </button>
            );
          })}
        </div>

        <p className="text-sm text-center mt-4" style={{ color: '#737877' }}>
          Your preference will be saved automatically
        </p>
      </div>
    </div>
  );
}
