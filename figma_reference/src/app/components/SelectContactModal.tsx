import { X, Search, Sparkles } from 'lucide-react';
import { useState } from 'react';
import { Contact } from './mock-data';

interface SelectContactModalProps {
  onClose: () => void;
  onSelectContact: (contact: Contact) => void;
  contacts: Contact[];
}

export function SelectContactModal({ onClose, onSelectContact, contacts }: SelectContactModalProps) {
  const [searchQuery, setSearchQuery] = useState('');

  const filteredContacts = contacts.filter(contact =>
    contact.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    contact.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
    contact.category.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-md w-full max-h-[80vh] flex flex-col transition-colors">
        <div className="p-6 border-b border-gray-200 dark:border-gray-700">
          <div className="flex justify-between items-center mb-4">
            <div className="flex items-center gap-2">
              <Sparkles size={24} style={{ color: '#C5A8E8' }} />
              <h2 className="text-xl font-semibold dark:text-white">Update with AI</h2>
            </div>
            <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full dark:text-white">
              <X size={24} />
            </button>
          </div>
          <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
            Select a contact to update using AI chat
          </p>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500" size={20} />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search contacts..."
              className="w-full pl-10 pr-4 py-2.5 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              autoFocus
            />
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {filteredContacts.length > 0 ? (
            <div className="space-y-2">
              {filteredContacts.map(contact => (
                <button
                  key={contact.id}
                  onClick={() => {
                    onSelectContact(contact);
                    onClose();
                  }}
                  className="w-full flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-left border border-transparent hover:border-purple-400"
                >
                  <span className="text-3xl flex-shrink-0">{contact.avatar}</span>
                  <div className="flex-1 min-w-0">
                    <div className="font-medium dark:text-white truncate">{contact.name}</div>
                    <div className="text-sm text-gray-600 dark:text-gray-400 truncate">{contact.email}</div>
                    <div className="text-xs text-gray-500 dark:text-gray-500 mt-0.5">{contact.category}</div>
                  </div>
                  <div className="flex flex-col items-center gap-1 flex-shrink-0">
                    <div className="relative w-10 h-10">
                      <svg className="w-10 h-10 transform -rotate-90">
                        <circle
                          cx="20"
                          cy="20"
                          r="16"
                          stroke="#e5e7eb"
                          strokeWidth="2.5"
                          fill="none"
                        />
                        <circle
                          cx="20"
                          cy="20"
                          r="16"
                          stroke="#C5A8E8"
                          strokeWidth="2.5"
                          fill="none"
                          strokeDasharray={`${(contact.bondScore / 100) * 100.5} ${100.5 - (contact.bondScore / 100) * 100.5}`}
                          strokeLinecap="round"
                        />
                      </svg>
                      <span className="absolute inset-0 flex items-center justify-center text-xs font-semibold dark:text-white">
                        {contact.bondScore}
                      </span>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          ) : (
            <div className="text-center py-12 text-gray-500 dark:text-gray-400">
              <p>No contacts found</p>
              <p className="text-sm mt-1">Try a different search term</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
