import { Plus, TrendingUp, ArrowRight } from 'lucide-react';
import { useState } from 'react';
import { mockRecommendations, mockContacts } from './mock-data';

interface HomeTabProps {
  connectionScore: number;
  onAddConnection: () => void;
  onUpdateConnection: () => void;
  onViewRecommendations: () => void;
  onNavigateToContact: (contactId: string) => void;
}

export function HomeTab({
  connectionScore,
  onAddConnection,
  onUpdateConnection,
  onViewRecommendations,
  onNavigateToContact
}: HomeTabProps) {
  const [showFABMenu, setShowFABMenu] = useState(false);
  const circumference = 2 * Math.PI * 80;
  const scorePercentage = connectionScore / 100;
  const strokeDashoffset = circumference - scorePercentage * circumference;

  return (
    <div className="flex flex-col gap-6 p-4 min-h-screen relative">
      {/* Decorative Stars */}
      <div className="absolute top-8 right-8 text-purple-200 opacity-40 text-xl pointer-events-none">✦</div>
      <div className="absolute top-32 left-8 text-purple-200 opacity-30 text-sm pointer-events-none">✦</div>
      <div className="absolute bottom-40 right-12 text-purple-200 opacity-35 text-base pointer-events-none">✦</div>

      {/* Connection Score */}
      <div className="flex flex-col items-center justify-center py-8 relative">
        <div className="relative w-48 h-48 mb-6">
          <svg className="w-48 h-48 transform -rotate-90">
            <circle
              cx="96"
              cy="96"
              r="80"
              stroke="#F5F5F5"
              strokeWidth="14"
              fill="none"
            />
            <circle
              cx="96"
              cy="96"
              r="80"
              stroke="url(#scoreGradient)"
              strokeWidth="14"
              fill="none"
              strokeDasharray={circumference}
              strokeDashoffset={strokeDashoffset}
              strokeLinecap="round"
              className="transition-all duration-1000"
            />
            <defs>
              <linearGradient id="scoreGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#7C34ED" />
                <stop offset="100%" stopColor="#7C34ED" />
              </linearGradient>
            </defs>
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="text-5xl font-bold" style={{ color: '#7C34ED' }}>
              {connectionScore}
            </span>
            <span className="text-sm font-semibold" style={{ color: '#6B7280' }}>
              Connection Score
            </span>
          </div>
        </div>

        <div className="flex items-center gap-2" style={{ color: '#6B7280' }}>
          <TrendingUp size={18} style={{ color: '#7C34ED' }} />
          <span className="text-sm font-medium">Keep nurturing your relationships!</span>
        </div>
      </div>

      <div className="bg-white rounded-3xl p-6 shadow-lg">
        <div className="flex justify-between items-center mb-4">
          <h3 className="font-bold" style={{ color: '#1B1B1B' }}>Top Recommendations</h3>
          <button
            onClick={onViewRecommendations}
            className="text-sm flex items-center gap-1 font-semibold hover:opacity-80 transition-opacity"
            style={{ color: '#7C34ED' }}
          >
            View All <ArrowRight size={16} />
          </button>
        </div>
        <div className="space-y-3">
          {mockRecommendations.slice(0, 2).map(rec => {
            const contact = mockContacts.find(c => c.id === rec.contactId);
            return (
              <button
                key={rec.contactId}
                onClick={() => onNavigateToContact(rec.contactId)}
                className="w-full flex items-center gap-3 p-4 rounded-2xl hover:shadow-md transition-all text-left bg-white border"
                style={{ borderColor: 'rgba(0, 0, 0, 0.08)' }}
              >
                <span className="text-3xl flex-shrink-0 w-10">{contact?.avatar}</span>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold truncate" style={{ color: '#1B1B1B' }}>{rec.contactName}</div>
                  <div className="text-sm truncate" style={{ color: '#6B7280' }}>{rec.reason}</div>
                </div>
                <div className="flex flex-col items-center gap-1 w-12 flex-shrink-0">
                  <div className="relative w-12 h-12">
                    <svg className="w-12 h-12 transform -rotate-90">
                      <circle
                        cx="24"
                        cy="24"
                        r="18"
                        stroke="#F5F5F5"
                        strokeWidth="3"
                        fill="none"
                      />
                      <circle
                        cx="24"
                        cy="24"
                        r="18"
                        stroke="#7C34ED"
                        strokeWidth="3"
                        fill="none"
                        strokeDasharray={`${(rec.bondScore / 100) * 113} ${113 - (rec.bondScore / 100) * 113}`}
                        strokeLinecap="round"
                      />
                    </svg>
                    <span className="absolute inset-0 flex items-center justify-center text-xs font-bold" style={{ color: '#1B1B1B' }}>
                      {rec.bondScore}
                    </span>
                  </div>
                  <span className={`text-xs px-2 py-1 rounded-full text-white whitespace-nowrap font-semibold`} style={{
                    backgroundColor: rec.priority === 'high' ? '#FF9F80' :
                      rec.priority === 'medium' ? '#FFB366' :
                      '#D4C5E8'
                  }}>
                    {rec.priority}
                  </span>
                </div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
