import { useState } from 'react';
import { Search, Filter } from 'lucide-react';
import { Contact } from './mock-data';

interface PeopleTabProps {
  contacts: Contact[];
  onContactClick: (contactId: string) => void;
  availableCategories: string[];
}

export function PeopleTab({ contacts, onContactClick, availableCategories }: PeopleTabProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const [sortBy, setSortBy] = useState<'name' | 'lastContact' | 'bondScore'>('name');

  const categories = ['All', ...availableCategories];

  const filteredContacts = contacts
    .filter(contact => {
      const matchesSearch = contact.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                           contact.email.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesCategory = selectedCategory === 'All' || contact.category === selectedCategory;
      return matchesSearch && matchesCategory;
    })
    .sort((a, b) => {
      if (sortBy === 'name') {
        return a.name.localeCompare(b.name);
      } else if (sortBy === 'lastContact') {
        return new Date(b.lastContact).getTime() - new Date(a.lastContact).getTime();
      } else {
        return b.bondScore - a.bondScore;
      }
    });

  return (
    <div className="p-4 min-h-screen relative">
      {/* Decorative Stars */}
      <div className="absolute top-12 right-6 text-purple-200 opacity-40 text-lg pointer-events-none">✦</div>
      <div className="absolute top-48 left-6 text-purple-200 opacity-30 text-sm pointer-events-none">✦</div>
      <div className="absolute bottom-32 right-10 text-purple-200 opacity-35 text-base pointer-events-none">✦</div>

      <div className="mb-4">
        <div className="relative mb-3">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500" size={20} />
          <input
            type="text"
            placeholder="Search contacts..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-3 rounded-full focus:outline-none focus:ring-2 bg-white shadow-md transition-all"
            style={{ color: '#1B1B1B' }}
            onFocus={(e) => {
              e.currentTarget.style.borderColor = '#7C34ED';
              e.currentTarget.style.boxShadow = '0 0 0 3px rgba(124, 52, 237, 0.2)';
            }}
            onBlur={(e) => {
              e.currentTarget.style.borderColor = '';
              e.currentTarget.style.boxShadow = '';
            }}
          />
        </div>

        <div className="flex items-center gap-2 overflow-x-auto pb-2">
          <Filter size={18} style={{ color: '#7C34ED' }} className="flex-shrink-0" />
          {categories.map(category => (
            <button
              key={category}
              onClick={() => setSelectedCategory(category)}
              className="px-4 py-2 rounded-full text-sm font-semibold whitespace-nowrap transition-all"
              style={{
                backgroundColor: selectedCategory === category ? '#7C34ED' : '#F5F5F5',
                color: selectedCategory === category ? 'white' : '#6B7280'
              }}
            >
              {category}
            </button>
          ))}
        </div>

        <div className="mt-4">
          <label className="block text-sm font-semibold mb-2" style={{ color: '#6B7280' }}>
            Sort by:
          </label>
          <div className="flex gap-2">
            <button
              onClick={() => setSortBy('name')}
              className="px-4 py-2 rounded-full text-sm font-semibold transition-all"
              style={{
                backgroundColor: sortBy === 'name' ? '#7C34ED' : '#F5F5F5',
                color: sortBy === 'name' ? 'white' : '#6B7280'
              }}
            >
              Name
            </button>
            <button
              onClick={() => setSortBy('lastContact')}
              className="px-4 py-2 rounded-full text-sm font-semibold transition-all"
              style={{
                backgroundColor: sortBy === 'lastContact' ? '#7C34ED' : '#F5F5F5',
                color: sortBy === 'lastContact' ? 'white' : '#6B7280'
              }}
            >
              Last Contact
            </button>
            <button
              onClick={() => setSortBy('bondScore')}
              className="px-4 py-2 rounded-full text-sm font-semibold transition-all"
              style={{
                backgroundColor: sortBy === 'bondScore' ? '#7C34ED' : '#F5F5F5',
                color: sortBy === 'bondScore' ? 'white' : '#6B7280'
              }}
            >
              Bond Score
            </button>
          </div>
        </div>
      </div>

      <div className="space-y-3">
        {filteredContacts.map(contact => (
          <button
            key={contact.id}
            onClick={() => onContactClick(contact.id)}
            className="w-full bg-white rounded-2xl p-4 shadow-lg transition-all text-left hover:shadow-xl hover:scale-[1.02]"
          >
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-full flex items-center justify-center text-2xl flex-shrink-0" style={{ backgroundColor: 'rgba(124, 52, 237, 0.15)' }}>
                {contact.avatar}
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-medium truncate dark:text-white">{contact.name}</div>
                <div className="text-sm truncate text-gray-600 dark:text-gray-400">{contact.email}</div>
                <div className="flex items-center gap-2 mt-1">
                  <span className="text-xs px-2 py-0.5 bg-gray-100 dark:bg-gray-700 rounded-full dark:text-gray-300">
                    {contact.category}
                  </span>
                </div>
              </div>
              <div className="flex flex-col items-end">
                <div className="w-12 h-12 rounded-full flex items-center justify-center relative">
                  <svg className="w-12 h-12 transform -rotate-90">
                    <circle
                      cx="24"
                      cy="24"
                      r="20"
                      stroke="#F5F5F5"
                      strokeWidth="4"
                      fill="none"
                    />
                    <circle
                      cx="24"
                      cy="24"
                      r="20"
                      stroke="#7C34ED"
                      strokeWidth="4"
                      fill="none"
                      strokeDasharray={`${contact.bondScore * 1.25} ${125 - contact.bondScore * 1.25}`}
                      strokeLinecap="round"
                    />
                  </svg>
                  <span className="absolute text-xs font-semibold">{contact.bondScore}</span>
                </div>
              </div>
            </div>
          </button>
        ))}
      </div>

      {filteredContacts.length === 0 && (
        <div className="text-center py-12 text-gray-500 dark:text-gray-400">
          No contacts found
        </div>
      )}
    </div>
  );
}
