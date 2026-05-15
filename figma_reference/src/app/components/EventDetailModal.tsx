import { X, Calendar, User, Repeat } from 'lucide-react';
import { Event, mockContacts } from './mock-data';

interface EventDetailModalProps {
  event: Event & { isRecurring?: boolean; recurrencePattern?: string };
  onClose: () => void;
  onDelete?: (eventId: string) => void;
  onViewContact?: (contactId: string) => void;
}

export function EventDetailModal({ event, onClose, onDelete, onViewContact }: EventDetailModalProps) {
  const contact = event.contactId ? mockContacts.find(c => c.id === event.contactId) : null;

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  const formatTime = (time: string) => {
    const [hours, minutes] = time.split(':');
    const hour = parseInt(hours);
    const ampm = hour >= 12 ? 'PM' : 'AM';
    const hour12 = hour % 12 || 12;
    return `${hour12}:${minutes} ${ampm}`;
  };

  const getEventTypeColor = (type: string) => {
    const colors = {
      'plan': '#C5A8E8',
      'reminder': '#FF7F50',
      'birthday': '#A96039'
    };
    return colors[type as keyof typeof colors] || '#C5A8E8';
  };

  const getEventTypeLabel = (type: string) => {
    const labels = {
      'plan': 'Plan',
      'reminder': 'Reminder',
      'birthday': 'Birthday'
    };
    return labels[type as keyof typeof labels] || 'Event';
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-md w-full p-6 transition-colors">
        <div className="flex justify-between items-start mb-4">
          <div className="flex-1">
            <h2 className="text-xl font-semibold dark:text-white mb-2">{event.title}</h2>
            <div
              className="inline-block px-3 py-1 rounded-full text-xs font-medium text-white"
              style={{ backgroundColor: getEventTypeColor(event.type) }}
            >
              {getEventTypeLabel(event.type)}
            </div>
          </div>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full dark:text-white">
            <X size={24} />
          </button>
        </div>

        <div className="space-y-4">
          <div className="flex items-start gap-3 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
            <Calendar size={20} className="mt-0.5 flex-shrink-0" style={{ color: '#C5A8E8' }} />
            <div className="flex-1">
              <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Date</div>
              <div className="font-medium dark:text-white">{formatDate(event.date)}</div>
              {!event.isAllDay && event.startTime && event.endTime && (
                <div className="mt-2 pt-2 border-t border-gray-200 dark:border-gray-600">
                  <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Time</div>
                  <div className="font-medium text-purple-600 dark:text-purple-400">
                    {formatTime(event.startTime)} - {formatTime(event.endTime)}
                  </div>
                </div>
              )}
              {event.isAllDay && (
                <div className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  All day event
                </div>
              )}
            </div>
          </div>

          {event.isRecurring && event.recurrencePattern && (
            <div className="flex items-start gap-3 p-3 bg-purple-50 dark:bg-purple-900/20 rounded-lg border border-purple-200 dark:border-purple-800">
              <Repeat size={20} className="mt-0.5 flex-shrink-0 text-purple-600 dark:text-purple-400" />
              <div>
                <div className="text-sm text-purple-900 dark:text-purple-100 font-medium mb-1">Recurring Event</div>
                <div className="text-sm text-purple-700 dark:text-purple-300 capitalize">
                  Repeats {event.recurrencePattern}
                </div>
              </div>
            </div>
          )}

          {contact && (
            <div className="flex items-start gap-3 p-3 bg-purple-50 dark:bg-purple-900/20 rounded-lg border border-purple-200 dark:border-purple-800">
              <User size={20} className="mt-0.5 flex-shrink-0" style={{ color: '#C5A8E8' }} />
              <div className="flex-1">
                <div className="text-sm text-purple-900 dark:text-purple-100 mb-1">Linked Contact</div>
                <div className="flex items-center gap-2">
                  <span className="text-xl">{contact.avatar}</span>
                  <div>
                    <div className="font-medium text-purple-900 dark:text-purple-100">{contact.name}</div>
                    <div className="text-sm text-purple-600 dark:text-purple-300">{contact.email}</div>
                  </div>
                </div>
                {onViewContact && (
                  <button
                    onClick={() => {
                      onViewContact(contact.id);
                      onClose();
                    }}
                    className="mt-2 text-sm font-medium hover:underline"
                    style={{ color: '#C5A8E8' }}
                  >
                    View Profile →
                  </button>
                )}
              </div>
            </div>
          )}
        </div>

        <div className="flex gap-3 pt-4 mt-4 border-t border-gray-200 dark:border-gray-700">
          {onDelete && (
            <button
              onClick={() => {
                onDelete(event.id);
                onClose();
              }}
              className="flex-1 px-4 py-2 border border-red-300 dark:border-red-700 text-red-600 dark:text-red-400 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
            >
              Delete Event
            </button>
          )}
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2 text-white rounded-lg hover:opacity-90 transition-opacity"
            style={{ backgroundColor: '#C5A8E8' }}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}