import { Home, Calendar, Users, Settings, Plus } from 'lucide-react';
import { useState } from 'react';

interface BottomNavProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
  onAddConnection: () => void;
  onUpdateConnection: () => void;
}

export function BottomNav({ activeTab, onTabChange, onAddConnection, onUpdateConnection }: BottomNavProps) {
  const [showFABMenu, setShowFABMenu] = useState(false);

  const tabs = [
    { id: 'home', label: 'Home', icon: Home },
    { id: 'people', label: 'People', icon: Users },
    { id: 'add', label: '', icon: Plus, isCenter: true },
    { id: 'planner', label: 'Planner', icon: Calendar },
    { id: 'settings', label: 'Settings', icon: Settings }
  ];

  const handleCenterButtonClick = () => {
    setShowFABMenu(!showFABMenu);
  };

  return (
    <>
      {showFABMenu && (
        <>
          <div
            className="fixed inset-0 z-40"
            onClick={() => setShowFABMenu(false)}
          />
          <div className="fixed bottom-20 left-1/2 -translate-x-1/2 z-50 space-y-2">
            <button
              onClick={() => {
                onAddConnection();
                setShowFABMenu(false);
              }}
              className="w-full bg-white px-6 py-3 rounded-full shadow-lg hover:shadow-xl hover:scale-105 transition-all whitespace-nowrap font-semibold"
              style={{ color: '#7C34ED' }}
            >
              Add Connection
            </button>
            <button
              onClick={() => {
                onUpdateConnection();
                setShowFABMenu(false);
              }}
              className="w-full bg-white px-6 py-3 rounded-full shadow-lg hover:shadow-xl hover:scale-105 transition-all whitespace-nowrap font-semibold"
              style={{ color: '#7C34ED' }}
            >
              Update Connection
            </button>
          </div>
        </>
      )}

      <nav className="fixed bottom-0 left-0 right-0 bg-white shadow-2xl z-50 transition-colors" style={{ borderTop: '1px solid rgba(124, 52, 237, 0.15)' }}>
        <div className="flex justify-around items-center h-16 relative">
          {tabs.map(tab => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;

            if (tab.isCenter) {
              return (
                <div key={tab.id} className="flex-1 flex justify-center items-center">
                  <button
                    onClick={handleCenterButtonClick}
                    className="w-16 h-16 rounded-full shadow-2xl hover:scale-110 transition-all flex items-center justify-center text-white -mt-8 border-4 border-white"
                    style={{
                      backgroundColor: '#7C34ED',
                      boxShadow: '0 8px 20px rgba(124, 52, 237, 0.4)'
                    }}
                  >
                    <Plus size={32} strokeWidth={2.5} className={`transition-transform ${showFABMenu ? 'rotate-45' : ''}`} />
                  </button>
                </div>
              );
            }

            return (
              <button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className="flex flex-col items-center justify-center flex-1 h-full transition-all"
                style={{ color: isActive ? '#7C34ED' : '#6B7280' }}
              >
                <Icon size={24} strokeWidth={isActive ? 2.5 : 2} />
                <span className={`text-xs mt-1 ${isActive ? 'font-semibold' : 'font-medium'}`}>{tab.label}</span>
              </button>
            );
          })}
        </div>
      </nav>
    </>
  );
}
