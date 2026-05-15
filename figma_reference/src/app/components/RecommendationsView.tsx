import { ArrowLeft, AlertCircle } from 'lucide-react';
import { mockRecommendations, mockContacts } from './mock-data';

interface RecommendationsViewProps {
  onBack: () => void;
  onNavigateToContact: (contactId: string) => void;
}

export function RecommendationsView({ onBack, onNavigateToContact }: RecommendationsViewProps) {
  return (
    <div className="min-h-screen bg-background pb-16 transition-colors">
      <div className="text-white p-4" style={{ backgroundColor: '#7C34ED' }}>
        <button onClick={onBack} className="mb-4 flex items-center gap-2 hover:opacity-80">
          <ArrowLeft size={20} />
          <span>Back to Home</span>
        </button>
        <h1 className="text-xl font-bold">Outreach Recommendations</h1>
        <p className="text-sm opacity-90 mt-1">AI-suggested contacts to reconnect with</p>
      </div>

      <div className="p-4">
        <div className="space-y-3">
          {mockRecommendations.map(rec => {
            const contact = mockContacts.find(c => c.id === rec.contactId);
            if (!contact) return null;

            return (
              <button
                key={rec.contactId}
                onClick={() => onNavigateToContact(rec.contactId)}
                className="w-full bg-white rounded-3xl p-4 shadow-lg hover:shadow-xl hover:scale-[1.02] transition-all text-left"
              >
                <div className="flex items-start gap-3">
                  <div className="w-12 h-12 rounded-full flex items-center justify-center text-2xl flex-shrink-0" style={{ backgroundColor: 'rgba(124, 52, 237, 0.15)' }}>
                    {contact.avatar}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-bold mb-1" style={{ color: '#1B1B1B' }}>{rec.contactName}</div>
                    <div className="flex items-start gap-2 mb-2">
                      <AlertCircle
                        size={16}
                        className="flex-shrink-0 mt-0.5"
                        style={{
                          color: rec.priority === 'high' ? '#FF9F80' :
                            rec.priority === 'medium' ? '#FFB366' :
                            '#D4C5E8'
                        }}
                      />
                      <span className="text-sm font-medium" style={{ color: '#6B7280' }}>{rec.reason}</span>
                    </div>
                    <div className="flex items-start gap-1.5 text-xs px-3 py-2 rounded-full mb-2" style={{ backgroundColor: '#F9F6FF', color: '#7C34ED' }}>
                      <span className="mt-0.5">💬</span>
                      <span className="italic font-medium">"{rec.topic}"</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-xs px-2 py-1 rounded-full font-semibold" style={{ backgroundColor: '#F9F6FF', color: '#6B7280' }}>
                        {contact.category}
                      </span>
                      <span className="text-xs px-2 py-1 rounded-full font-semibold text-white" style={{
                        backgroundColor: rec.priority === 'high' ? '#FF9F80' :
                          rec.priority === 'medium' ? '#FFB366' :
                          '#D4C5E8'
                      }}>
                        {rec.priority} priority
                      </span>
                    </div>
                  </div>
                  <div className="flex flex-col items-center">
                    <div className="relative w-14 h-14">
                      <svg className="w-14 h-14 transform -rotate-90">
                        <circle
                          cx="28"
                          cy="28"
                          r="22"
                          stroke="rgba(124, 52, 237, 0.2)"
                          strokeWidth="4"
                          fill="none"
                        />
                        <circle
                          cx="28"
                          cy="28"
                          r="22"
                          stroke="#7C34ED"
                          strokeWidth="4"
                          fill="none"
                          strokeDasharray={`${(rec.bondScore / 100) * 138} ${138 - (rec.bondScore / 100) * 138}`}
                          strokeLinecap="round"
                        />
                      </svg>
                      <span className="absolute inset-0 flex items-center justify-center text-sm font-bold" style={{ color: '#1B1B1B' }}>
                        {rec.bondScore}
                      </span>
                    </div>
                    <span className="text-xs mt-1 font-semibold" style={{ color: '#6B7280' }}>Score</span>
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
