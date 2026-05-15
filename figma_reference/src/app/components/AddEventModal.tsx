import { X, Search } from 'lucide-react';
import { useState, useEffect } from 'react';
import { mockContacts, Event } from './mock-data';

interface AddEventModalProps {
  selectedDate: string;
  onClose: () => void;
  onSave: (event: {
    id?: string;
    date: string;
    title: string;
    contactId?: string;
    type: string;
    isRecurring?: boolean;
    recurrencePattern?: 'daily' | 'weekly' | 'monthly' | 'yearly';
    isAllDay?: boolean;
    startTime?: string;
    endTime?: string;
  }) => void;
  event?: Event & { isRecurring?: boolean; recurrencePattern?: string };
  onDelete?: (eventId: string) => void;
  availableEventTypes: string[];
}

export function AddEventModal({ selectedDate, onClose, onSave, event, onDelete, availableEventTypes }: AddEventModalProps) {
  const isEditMode = !!event;

  const [date, setDate] = useState(event?.date || selectedDate);
  const [title, setTitle] = useState(event?.title || '');
  const [contactId, setContactId] = useState(event?.contactId || '');
  const [contactSearch, setContactSearch] = useState('');
  const [showContactDropdown, setShowContactDropdown] = useState(false);
  const [eventType, setEventType] = useState<string>(event?.type || availableEventTypes[0] || 'Plan');
  const [isRecurring, setIsRecurring] = useState(event?.isRecurring || false);
  const [recurrencePattern, setRecurrencePattern] = useState<'daily' | 'weekly' | 'monthly' | 'yearly'>(event?.recurrencePattern || 'weekly');
  const [isAllDay, setIsAllDay] = useState(event?.isAllDay !== false);
  const [startTime, setStartTime] = useState(event?.startTime || '09:00');
  const [endTime, setEndTime] = useState(event?.endTime || '10:00');

  // Set initial contact search value if editing
  useEffect(() => {
    if (event?.contactId) {
      const contact = mockContacts.find(c => c.id === event.contactId);
      if (contact) {
        setContactSearch(contact.name);
      }
    }
  }, [event]);

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  const filteredContacts = mockContacts.filter(contact =>
    contact.name.toLowerCase().includes(contactSearch.toLowerCase()) ||
    contact.email.toLowerCase().includes(contactSearch.toLowerCase())
  );

  const selectedContact = mockContacts.find(c => c.id === contactId);

  const handleContactSelect = (id: string, name: string) => {
    setContactId(id);
    setContactSearch(name);
    setShowContactDropdown(false);
  };

  const handleContactSearchChange = (value: string) => {
    setContactSearch(value);
    setShowContactDropdown(true);
    if (!value) {
      setContactId('');
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (title.trim()) {
      onSave({
        id: event?.id,
        date,
        title,
        contactId: contactId || undefined,
        type: eventType,
        isRecurring: isRecurring,
        recurrencePattern: isRecurring ? recurrencePattern : undefined,
        isAllDay: isAllDay,
        startTime: isAllDay ? undefined : startTime,
        endTime: isAllDay ? undefined : endTime
      });
      onClose();
    }
  };

  const handleDelete = () => {
    if (event?.id && onDelete) {
      onDelete(event.id);
      onClose();
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-md w-full p-6 transition-colors">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-xl font-semibold dark:text-white">{isEditMode ? 'Edit Event' : 'Add Event'}</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full dark:text-white">
            <X size={24} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Event Title
            </label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              placeholder="e.g., Coffee with Sarah"
              required
              autoFocus
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Date
            </label>
            <input
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              required
            />
          </div>

          <div className="border-t border-gray-200 dark:border-gray-700 pt-4">
            <label className="flex items-center justify-between cursor-pointer mb-3">
              <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                All Day
              </span>
              <button
                type="button"
                onClick={() => setIsAllDay(!isAllDay)}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                  isAllDay ? 'bg-purple-500' : 'bg-gray-300 dark:bg-gray-600'
                }`}
              >
                <span
                  className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    isAllDay ? 'translate-x-6' : 'translate-x-1'
                  }`}
                />
              </button>
            </label>

            {!isAllDay && (
              <div className="grid grid-cols-2 gap-3 mt-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Start Time
                  </label>
                  <input
                    type="time"
                    value={startTime}
                    onChange={(e) => setStartTime(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    End Time
                  </label>
                  <input
                    type="time"
                    value={endTime}
                    onChange={(e) => setEndTime(e.target.value)}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  />
                </div>
              </div>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Event Type
            </label>
            <select
              value={eventType}
              onChange={(e) => setEventType(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            >
              {availableEventTypes.map((type) => (
                <option key={type} value={type}>
                  {type}
                </option>
              ))}
            </select>
          </div>

          <div className="relative">
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Link to Contact (Optional)
            </label>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500" size={20} />
              <input
                type="text"
                value={contactSearch}
                onChange={(e) => handleContactSearchChange(e.target.value)}
                onFocus={() => setShowContactDropdown(true)}
                className="w-full pl-10 pr-10 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                placeholder="Search contacts..."
              />
              {contactId && (
                <button
                  type="button"
                  onClick={() => {
                    setContactId('');
                    setContactSearch('');
                  }}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                >
                  <X size={16} />
                </button>
              )}
            </div>

            {showContactDropdown && contactSearch && filteredContacts.length > 0 && (
              <div className="absolute z-10 w-full mt-1 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg shadow-lg max-h-48 overflow-y-auto">
                {filteredContacts.map(contact => (
                  <button
                    key={contact.id}
                    type="button"
                    onClick={() => handleContactSelect(contact.id, contact.name)}
                    className="w-full px-4 py-2 text-left hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors flex items-center gap-3"
                  >
                    <span className="text-xl">{contact.avatar}</span>
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-gray-900 dark:text-white truncate">{contact.name}</div>
                      <div className="text-sm text-gray-500 dark:text-gray-400 truncate">{contact.email}</div>
                    </div>
                  </button>
                ))}
              </div>
            )}

            {contactSearch && filteredContacts.length === 0 && showContactDropdown && (
              <div className="absolute z-10 w-full mt-1 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg shadow-lg p-4 text-center text-sm text-gray-500 dark:text-gray-400">
                No contacts found
              </div>
            )}

            {selectedContact && (
              <div className="mt-2 p-2 bg-purple-50 dark:bg-purple-900/20 rounded-lg flex items-center gap-2">
                <span className="text-lg">{selectedContact.avatar}</span>
                <span className="text-sm text-purple-900 dark:text-purple-100">{selectedContact.name}</span>
              </div>
            )}
          </div>

          <div className="border-t border-gray-200 dark:border-gray-700 pt-4">
            <label className="flex items-center justify-between cursor-pointer">
              <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
                Recurring Event
              </span>
              <button
                type="button"
                onClick={() => setIsRecurring(!isRecurring)}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                  isRecurring ? 'bg-purple-500' : 'bg-gray-300 dark:bg-gray-600'
                }`}
              >
                <span
                  className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                    isRecurring ? 'translate-x-6' : 'translate-x-1'
                  }`}
                />
              </button>
            </label>

            {isRecurring && (
              <div className="mt-3">
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Repeat
                </label>
                <select
                  value={recurrencePattern}
                  onChange={(e) => setRecurrencePattern(e.target.value as 'daily' | 'weekly' | 'monthly' | 'yearly')}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-400 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                >
                  <option value="daily">Daily</option>
                  <option value="weekly">Weekly</option>
                  <option value="monthly">Monthly</option>
                  <option value="yearly">Yearly</option>
                </select>
                <p className="mt-2 text-xs text-gray-500 dark:text-gray-400">
                  {recurrencePattern === 'daily' && 'Repeats every day'}
                  {recurrencePattern === 'weekly' && `Repeats every week on ${new Date(date).toLocaleDateString('en-US', { weekday: 'long' })}`}
                  {recurrencePattern === 'monthly' && `Repeats on day ${new Date(date).getDate()} of every month`}
                  {recurrencePattern === 'yearly' && `Repeats every year on ${new Date(date).toLocaleDateString('en-US', { month: 'long', day: 'numeric' })}`}
                </p>
              </div>
            )}
          </div>

          <div className="flex gap-3 pt-2">
            {isEditMode && onDelete ? (
              <>
                <button
                  type="button"
                  onClick={onClose}
                  className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors dark:text-white"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleDelete}
                  className="px-4 py-2 border border-red-300 dark:border-red-700 text-red-600 dark:text-red-400 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                >
                  Delete
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 text-white rounded-lg hover:opacity-90 transition-opacity"
                  style={{ backgroundColor: '#C5A8E8' }}
                >
                  Save
                </button>
              </>
            ) : (
              <>
                <button
                  type="button"
                  onClick={onClose}
                  className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors dark:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 text-white rounded-lg hover:opacity-90 transition-opacity"
                  style={{ backgroundColor: '#C5A8E8' }}
                >
                  Add Event
                </button>
              </>
            )}
          </div>
        </form>
      </div>
    </div>
  );
}