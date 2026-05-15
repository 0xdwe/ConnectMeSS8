import { ArrowLeft, TrendingUp } from 'lucide-react';
import { useState } from 'react';
import { mockContacts } from './mock-data';

interface ProfileViewProps {
  user: {
    name: string;
    email: string;
    avatar: string;
    connectionScore: number;
    totalConnections: number;
    heatmapData: number[];
  };
  onBack: () => void;
}

export function ProfileView({ user, onBack }: ProfileViewProps) {
  const [hoveredCell, setHoveredCell] = useState<{ category: string; month: number; count: number } | null>(null);
  // Group contacts by category and calculate heatmap for each
  const categories = ['Family', 'Friends', 'High School', 'College', 'Work', 'Other'] as const;

  const categoryHeatmaps = categories.map(category => {
    const categoryContacts = mockContacts.filter(c => c.category === category);
    if (categoryContacts.length === 0) return null;

    // Calculate average interaction frequency for this category
    const heatmapData = Array(12).fill(0);
    categoryContacts.forEach(contact => {
      contact.interactionFrequency.forEach((freq, idx) => {
        heatmapData[idx] += freq;
      });
    });

    // Average it out
    const avgHeatmapData = heatmapData.map(val => Math.round(val / categoryContacts.length));
    const maxActivity = Math.max(...avgHeatmapData);

    return {
      category,
      data: avgHeatmapData,
      maxActivity,
      count: categoryContacts.length
    };
  }).filter(Boolean);

  const getCategoryColor = (category: string) => {
    const colors: Record<string, string> = {
      'Family': '139, 111, 209',      // Purple
      'Friends': '125, 211, 192',     // Teal
      'High School': '255, 179, 102', // Orange
      'College': '168, 197, 232',     // Blue
      'Work': '255, 179, 199',        // Pink
      'Other': '197, 168, 232'        // Light Purple
    };
    return colors[category] || '139, 111, 209';
  };

  const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  return (
    <div className="min-h-screen bg-background pb-16 transition-colors">
      <div className="text-white p-4" style={{ backgroundColor: '#7C34ED' }}>
        <button onClick={onBack} className="mb-4 flex items-center gap-2 hover:opacity-80">
          <ArrowLeft size={20} />
          <span>Back</span>
        </button>
        <div className="text-center">
          <div className="w-20 h-20 mx-auto mb-3 rounded-full bg-white/20 backdrop-blur-sm text-4xl flex items-center justify-center border-2 border-white/40">
            {user.avatar}
          </div>
          <h1 className="text-xl font-bold mb-1">{user.name}</h1>
          <p className="text-sm opacity-90">{user.email}</p>
        </div>
      </div>

      <div className="p-4">
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div className="bg-white rounded-3xl p-4 shadow-lg text-center">
            <div className="text-3xl font-bold" style={{ color: '#C5A8E8' }}>{user.connectionScore}</div>
            <div className="text-sm mt-1 font-semibold" style={{ color: '#6B7280' }}>Connection Score</div>
          </div>
          <div className="bg-white rounded-3xl p-4 shadow-lg text-center">
            <div className="text-3xl font-bold" style={{ color: '#FF9F80' }}>{user.totalConnections}</div>
            <div className="text-sm mt-1 font-semibold" style={{ color: '#6B7280' }}>Total Connections</div>
          </div>
        </div>

        <div className="bg-white rounded-3xl p-4 shadow-lg">
          <div className="flex items-center gap-2 mb-3">
            <TrendingUp size={18} style={{ color: '#C5A8E8' }} />
            <h3 className="font-bold" style={{ color: '#1B1B1B' }}>Connection Heatmap by Category</h3>
          </div>
          <p className="text-sm mb-4 font-medium" style={{ color: '#6B7280' }}>Your social activity over the last 12 months</p>

          <div className="space-y-4">
            {categoryHeatmaps.map((heatmap) => {
              if (!heatmap) return null;
              const categoryColor = getCategoryColor(heatmap.category);

              return (
                <div key={heatmap.category}>
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <div
                        className="w-3 h-3 rounded-full"
                        style={{ backgroundColor: `rgb(${categoryColor})` }}
                      />
                      <span className="text-sm font-medium dark:text-white">{heatmap.category}</span>
                      <span className="text-xs text-gray-500 dark:text-gray-400">
                        ({heatmap.count} {heatmap.count === 1 ? 'contact' : 'contacts'})
                      </span>
                    </div>
                  </div>
                  <div className="grid grid-cols-12 gap-1 relative">
                    {heatmap.data.map((activity, idx) => {
                      const intensity = heatmap.maxActivity > 0 ? activity / heatmap.maxActivity : 0;
                      const isHovered = hoveredCell?.category === heatmap.category && hoveredCell?.month === idx;

                      return (
                        <div key={idx} className="relative">
                          <button
                            className="aspect-square w-full rounded-sm hover:ring-2 hover:ring-offset-1 transition-all cursor-pointer"
                            style={{
                              backgroundColor: intensity === 0
                                ? '#e5e7eb'
                                : `rgba(${categoryColor}, ${0.2 + intensity * 0.8})`,
                              '--tw-ring-color': `rgb(${categoryColor})`
                            } as React.CSSProperties}
                            onMouseEnter={() => setHoveredCell({ category: heatmap.category, month: idx, count: activity })}
                            onMouseLeave={() => setHoveredCell(null)}
                          />
                          {isHovered && (
                            <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 z-50 pointer-events-none">
                              <div className="bg-gray-900 dark:bg-gray-700 text-white px-3 py-2 rounded-lg shadow-lg whitespace-nowrap">
                                <div className="text-xs font-medium mb-0.5">
                                  {heatmap.category} - {monthNames[idx]}
                                </div>
                                <div className="text-sm font-bold">
                                  {activity} interactions
                                </div>
                                <div className="absolute top-full left-1/2 -translate-x-1/2 -mt-1">
                                  <div className="border-4 border-transparent border-t-gray-900 dark:border-t-gray-700" />
                                </div>
                              </div>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
