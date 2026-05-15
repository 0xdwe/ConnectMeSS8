import { ChevronRight, User, Bell, Shield, Info, Palette, Tags, Calendar } from 'lucide-react';

interface SettingsTabProps {
  onEditProfile: () => void;
  onThemeClick: () => void;
  onManageCategories: () => void;
  onManageEventTypes: () => void;
}

export function SettingsTab({ onEditProfile, onThemeClick, onManageCategories, onManageEventTypes }: SettingsTabProps) {
  const settingSections = [
    {
      title: 'Account',
      items: [
        { icon: User, label: 'Edit Profile', onClick: onEditProfile },
        { icon: Bell, label: 'Notifications', onClick: () => {} },
        { icon: Shield, label: 'Privacy & Security', onClick: () => {} }
      ]
    },
    {
      title: 'Customization',
      items: [
        { icon: Palette, label: 'Theme', onClick: onThemeClick },
        { icon: Tags, label: 'Manage Categories', onClick: onManageCategories },
        { icon: Calendar, label: 'Manage Event Types', onClick: onManageEventTypes }
      ]
    },
    {
      title: 'About',
      items: [
        { icon: Info, label: 'About Connect Me', onClick: () => {} }
      ]
    }
  ];

  return (
    <div className="p-4">
      {settingSections.map((section, idx) => (
        <div key={idx} className="mb-6">
          <h3 className="text-sm font-bold mb-3 px-2" style={{ color: '#6B7280' }}>{section.title}</h3>
          <div className="bg-white rounded-3xl shadow-lg overflow-hidden">
            {section.items.map((item, itemIdx) => {
              const Icon = item.icon;
              return (
                <button
                  key={itemIdx}
                  onClick={item.onClick}
                  className={`w-full flex items-center gap-3 p-4 hover:bg-purple-50 transition-all ${
                    itemIdx !== section.items.length - 1 ? 'border-b' : ''
                  }`}
                  style={{
                    borderColor: itemIdx !== section.items.length - 1 ? 'rgba(124, 52, 237, 0.1)' : 'transparent'
                  }}
                >
                  <Icon size={20} style={{ color: '#7C34ED' }} />
                  <span className="flex-1 text-left font-medium" style={{ color: '#1B1B1B' }}>{item.label}</span>
                  <ChevronRight size={20} style={{ color: '#6B7280' }} />
                </button>
              );
            })}
          </div>
        </div>
      ))}

      <div className="mt-8 text-center text-sm font-medium" style={{ color: '#6B7280' }}>
        <p>Connect Me v3.0</p>
        <p className="mt-1">Making relationships matter</p>
      </div>
    </div>
  );
}
