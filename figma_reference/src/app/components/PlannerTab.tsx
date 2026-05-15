import { useState, useRef, useEffect } from 'react';
import { ChevronLeft, ChevronRight, Plus, X, Search } from 'lucide-react';
import { Event, mockContacts } from './mock-data';

interface PlannerTabProps {
  events: Event[];
  onEventClick: (event: Event) => void;
  onAddEvent: (date: string) => void;
}

export function PlannerTab({ events, onEventClick, onAddEvent }: PlannerTabProps) {
  const [currentDate, setCurrentDate] = useState(new Date(2026, 3, 27));
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const [showAllEvents, setShowAllEvents] = useState(false);
  const [showMonthPicker, setShowMonthPicker] = useState(false);
  const [showSearch, setShowSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [touchStart, setTouchStart] = useState<number | null>(null);
  const [touchEnd, setTouchEnd] = useState<number | null>(null);
  const upcomingEventsRef = useRef<HTMLDivElement>(null);

  // Minimum swipe distance (in px)
  const minSwipeDistance = 50;

  const daysInMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate();
  const firstDay = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1).getDay();

  const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];

  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  const goToPrevMonth = () => {
    setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1));
  };

  const goToNextMonth = () => {
    setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1));
  };

  const hasEvent = (day: number) => {
    const dateStr = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    return displayedEvents.filter(e => e.date === dateStr);
  };

  const handleDateClick = (dateStr: string) => {
    // If clicking the same date, toggle it off; otherwise, update to the new date
    if (selectedDate === dateStr) {
      setSelectedDate(null);
    } else {
      setSelectedDate(dateStr);
      // Scroll to upcoming events section
      setTimeout(() => {
        upcomingEventsRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, 100);
    }
  };

  const groupEventsByDate = (eventsList: Event[]) => {
    const grouped: { [key: string]: Event[] } = {};
    eventsList.forEach(event => {
      if (!grouped[event.date]) {
        grouped[event.date] = [];
      }
      grouped[event.date].push(event);
    });
    return grouped;
  };

  const formatDateHeader = (dateStr: string) => {
    const date = new Date(dateStr);
    const today = new Date('2026-04-27');
    const tomorrow = new Date('2026-04-28');

    if (dateStr === '2026-04-27') return 'Today';
    if (dateStr === '2026-04-28') return 'Tomorrow';

    return date.toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'long',
      day: 'numeric',
      year: date.getFullYear() !== today.getFullYear() ? 'numeric' : undefined
    });
  };

  const getEventTypeColor = (type: string) => {
    const colors: { [key: string]: string } = {
      'Plan': '#7C34ED',
      'Reminder': '#FF9F80',
      'Birthday': '#FFB3C7',
      'Meeting': '#A8C5E8',
      'Call': '#D4C5E8',
      'Dinner': '#FFB366',
      'Coffee': '#E8D9F5'
    };
    return colors[type] || '#7C34ED';
  };

  const formatTime = (time: string) => {
    const [hours, minutes] = time.split(':');
    const hour = parseInt(hours);
    const ampm = hour >= 12 ? 'PM' : 'AM';
    const hour12 = hour % 12 || 12;
    return `${hour12}:${minutes} ${ampm}`;
  };

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && showSearch) {
        setShowSearch(false);
      }
    };
    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [showSearch]);

  const onTouchStart = (e: React.TouchEvent) => {
    setTouchEnd(null);
    setTouchStart(e.targetTouches[0].clientX);
  };

  const onTouchMove = (e: React.TouchEvent) => {
    setTouchEnd(e.targetTouches[0].clientX);
  };

  const onTouchEnd = () => {
    if (!touchStart || !touchEnd) return;

    const distance = touchStart - touchEnd;
    const isLeftSwipe = distance > minSwipeDistance;
    const isRightSwipe = distance < -minSwipeDistance;

    if (isLeftSwipe) {
      goToNextMonth();
    }
    if (isRightSwipe) {
      goToPrevMonth();
    }
  };

  const getFilteredEvents = () => {
    if (!searchQuery.trim()) return events;

    const query = searchQuery.toLowerCase();
    return events.filter(event => {
      const titleMatch = event.title.toLowerCase().includes(query);
      const contact = event.contactId ? mockContacts.find(c => c.id === event.contactId) : null;
      const contactMatch = contact ? contact.name.toLowerCase().includes(query) : false;
      return titleMatch || contactMatch;
    });
  };

  const displayedEvents = searchQuery.trim() ? getFilteredEvents() : events;

  return (
    <div className="p-4 min-h-screen relative">
      {/* Decorative Stars */}
      <div className="absolute top-10 left-8 text-purple-200 opacity-40 text-xl pointer-events-none">✦</div>
      <div className="absolute top-40 right-6 text-purple-200 opacity-30 text-sm pointer-events-none">✦</div>
      <div className="absolute bottom-36 left-10 text-purple-200 opacity-35 text-base pointer-events-none">✦</div>

      {/* Header with title and action buttons */}
      <div className="flex justify-between items-center mb-4">
        <div className="flex items-center gap-2">
          <button
            onClick={goToPrevMonth}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg dark:text-white transition-colors"
            title="Previous Month"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <div className="min-w-[200px] flex justify-center">
            <button
              onClick={() => setShowMonthPicker(true)}
              className="px-3 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
            >
              <h2 className="font-semibold dark:text-white">
                {monthNames[currentDate.getMonth()]} {currentDate.getFullYear()}
              </h2>
            </button>
          </div>
          <button
            onClick={goToNextMonth}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg dark:text-white transition-colors"
            title="Next Month"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowSearch(true)}
            className="p-2 rounded-lg text-white hover:opacity-90 transition-opacity"
            style={{ backgroundColor: '#7C34ED' }}
            title="Search Events"
          >
            <Search size={20} />
          </button>
          <button
            onClick={() => onAddEvent(selectedDate || '2026-04-27')}
            className="p-2 rounded-lg text-white hover:opacity-90 transition-opacity"
            style={{ backgroundColor: '#7C34ED' }}
            title="Add Event"
          >
            <Plus size={20} />
          </button>
        </div>
      </div>

      {/* Calendar with side navigation */}
      <div className="relative">
        {/* Calendar container */}
        <div
          className="bg-white rounded-3xl shadow-lg p-4 sm:p-6 transition-colors mx-auto max-w-4xl"
          onTouchStart={onTouchStart}
          onTouchMove={onTouchMove}
          onTouchEnd={onTouchEnd}
        >
          <div className="grid grid-cols-7 gap-1 sm:gap-2 mb-2">
            {days.map(day => (
              <div key={day} className="text-center text-xs sm:text-sm text-gray-500 dark:text-gray-400 font-medium py-2">
                {day}
              </div>
            ))}
          </div>

          <div className="grid grid-cols-7 gap-1 sm:gap-2">
          {Array.from({ length: firstDay }).map((_, i) => (
            <div key={`empty-${i}`} className="aspect-square" />
          ))}
          {Array.from({ length: daysInMonth }).map((_, i) => {
            const day = i + 1;
            const dayEvents = hasEvent(day);
            const isToday = day === 27 && currentDate.getMonth() === 3;
            const dateStr = `${currentDate.getFullYear()}-${String(currentDate.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

            return (
              <button
                key={day}
                onClick={() => handleDateClick(dateStr)}
                className={`aspect-square flex flex-col items-center justify-center rounded-lg text-sm sm:text-base relative transition-all ${
                  isToday
                    ? 'text-white font-semibold'
                    : selectedDate === dateStr
                    ? 'border-2 dark:text-white font-medium'
                    : dayEvents.length > 0
                    ? 'bg-gray-50 dark:bg-gray-700/50 hover:bg-gray-100 dark:hover:bg-gray-700 dark:text-gray-300 cursor-pointer font-medium'
                    : 'hover:bg-gray-100 dark:hover:bg-gray-700 dark:text-gray-300 cursor-pointer'
                }`}
                style={
                  isToday
                    ? { backgroundColor: '#7C34ED' }
                    : selectedDate === dateStr
                    ? { backgroundColor: '#F9F6FF', borderColor: '#7C34ED' }
                    : undefined
                }
              >
                {day}
                {dayEvents.length > 0 && (
                  <div className="flex gap-0.5 mt-1">
                    {dayEvents.slice(0, 3).map((event, idx) => (
                      <div
                        key={idx}
                        className={`w-1.5 h-1.5 sm:w-2 sm:h-2 rounded-full ${isToday ? 'bg-white' : ''}`}
                        style={!isToday ? { backgroundColor: getEventTypeColor(event.type) } : {}}
                      />
                    ))}
                  </div>
                )}
              </button>
            );
          })}
          </div>
        </div>
      </div>

      <div className="mt-6" ref={upcomingEventsRef}>
        <div className="flex justify-between items-center mb-4">
          <h3 className="font-semibold text-lg dark:text-white">
            {searchQuery.trim() ? 'Search Results' : 'Upcoming Events'}
          </h3>
          {!showAllEvents && !searchQuery.trim() && displayedEvents.filter(event => new Date(event.date) >= new Date('2026-04-27')).length > 5 && (
            <button
              onClick={() => setShowAllEvents(true)}
              className="text-sm font-medium hover:underline"
              style={{ color: '#7C34ED' }}
            >
              Show All ({displayedEvents.filter(event => new Date(event.date) >= new Date('2026-04-27')).length})
            </button>
          )}
          {showAllEvents && !searchQuery.trim() && (
            <button
              onClick={() => setShowAllEvents(false)}
              className="text-sm font-medium hover:underline"
              style={{ color: '#7C34ED' }}
            >
              Show Less
            </button>
          )}
        </div>

        {searchQuery.trim() && (
          <div className="mb-4 p-3 bg-orange-50 dark:bg-orange-900/20 rounded-lg border border-orange-200 dark:border-orange-800 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Search size={16} className="text-orange-700 dark:text-orange-400" />
              <span className="text-sm font-medium text-orange-900 dark:text-orange-100">
                Searching for: "{searchQuery}"
              </span>
            </div>
            <button
              onClick={() => {
                setSearchQuery('');
                setSelectedDate(null);
              }}
              className="p-1 hover:bg-orange-100 dark:hover:bg-orange-900/40 rounded-full text-orange-700 dark:text-orange-300"
            >
              <X size={16} />
            </button>
          </div>
        )}

        {selectedDate && !searchQuery.trim() && (
          <div className="mb-4 p-3 bg-purple-50 dark:bg-purple-900/20 rounded-lg border border-purple-200 dark:border-purple-800 flex items-center justify-between">
            <span className="text-sm font-medium text-purple-900 dark:text-purple-100">
              Showing events for {formatDateHeader(selectedDate)}
            </span>
            <button
              onClick={() => setSelectedDate(null)}
              className="p-1 hover:bg-purple-100 dark:hover:bg-purple-900/40 rounded-full text-purple-600 dark:text-purple-300"
            >
              <X size={16} />
            </button>
          </div>
        )}

        <div className="space-y-4">
          {(() => {
            const upcomingEvents = displayedEvents
              .filter(event => searchQuery.trim() || new Date(event.date) >= new Date('2026-04-27'))
              .filter(event => !selectedDate || event.date === selectedDate)
              .sort((a, b) => {
                const dateCompare = new Date(a.date).getTime() - new Date(b.date).getTime();
                if (dateCompare !== 0) return dateCompare;

                // If dates are the same, sort by time (all-day events first, then by start time)
                if (a.isAllDay && !b.isAllDay) return -1;
                if (!a.isAllDay && b.isAllDay) return 1;
                if (!a.isAllDay && !b.isAllDay && a.startTime && b.startTime) {
                  return a.startTime.localeCompare(b.startTime);
                }
                return 0;
              });

            const displayEvents = (showAllEvents || searchQuery.trim()) ? upcomingEvents : upcomingEvents.slice(0, 5);
            const groupedEvents = groupEventsByDate(displayEvents);

            if (Object.keys(groupedEvents).length === 0) {
              return (
                <div className="text-center py-12 bg-gray-50 dark:bg-gray-800 rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-700">
                  <div className="mb-4">
                    <p className="text-gray-700 dark:text-gray-300 font-medium mb-1">
                      {searchQuery.trim()
                        ? `No events found for "${searchQuery}"`
                        : selectedDate
                        ? `No events scheduled for ${formatDateHeader(selectedDate)}`
                        : 'No upcoming events'}
                    </p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      {searchQuery.trim()
                        ? 'Try a different search term'
                        : selectedDate
                        ? 'This day is free!'
                        : 'Your calendar is clear'}
                    </p>
                  </div>
                  {!searchQuery.trim() && (
                    <button
                      onClick={() => onAddEvent(selectedDate || '2026-04-27')}
                      className="px-4 py-2 rounded-lg text-white font-medium hover:opacity-90 transition-opacity inline-flex items-center gap-2"
                      style={{ backgroundColor: '#7C34ED' }}
                    >
                      <Plus size={18} />
                      Add Event{selectedDate ? ` for ${formatDateHeader(selectedDate)}` : ''}
                    </button>
                  )}
                </div>
              );
            }

            return Object.entries(groupedEvents).map(([date, dateEvents]) => (
              <div key={date} className="space-y-2">
                <div className="flex items-center gap-2">
                  <h4 className="font-semibold dark:text-white">{formatDateHeader(date)}</h4>
                  <div className="flex-1 h-px bg-gray-200 dark:bg-gray-700" />
                  <span className="text-xs text-gray-500 dark:text-gray-400">
                    {dateEvents.length} {dateEvents.length === 1 ? 'event' : 'events'}
                  </span>
                </div>

                <div className="space-y-2">
                  {dateEvents.map(event => {
                    const contact = event.contactId ? mockContacts.find(c => c.id === event.contactId) : null;
                    return (
                      <button
                        key={event.id}
                        onClick={() => onEventClick(event)}
                        className="w-full bg-white dark:bg-gray-800 rounded-lg p-4 shadow-sm border border-gray-200 dark:border-gray-700 hover:shadow-md hover:border-purple-400 transition-all text-left group"
                      >
                        <div className="flex items-start gap-3">
                          <div
                            className="w-1 h-full rounded-full flex-shrink-0 self-stretch"
                            style={{ backgroundColor: getEventTypeColor(event.type) }}
                          />
                          <div className="flex-1 min-w-0">
                            <div className="flex items-start justify-between gap-2 mb-1">
                              <h5 className="font-medium dark:text-white truncate group-hover:text-purple-600 dark:group-hover:text-purple-400 transition-colors">
                                {event.title}
                              </h5>
                              {contact && (
                                <span className="text-2xl flex-shrink-0">{contact.avatar}</span>
                              )}
                            </div>
                            <div className="flex items-center gap-2 flex-wrap text-sm">
                              {!event.isAllDay && event.startTime && event.endTime && (
                                <span className="font-medium text-purple-600 dark:text-purple-400">
                                  {formatTime(event.startTime)} - {formatTime(event.endTime)}
                                </span>
                              )}
                              {!event.isAllDay && event.startTime && event.endTime && contact && (
                                <span className="text-gray-400 dark:text-gray-500">•</span>
                              )}
                              {contact && (
                                <span className="text-gray-600 dark:text-gray-400">with {contact.name}</span>
                              )}
                            </div>
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>
            ));
          })()}
        </div>
      </div>

      {/* Search Modal */}
      {showSearch && (
        <div
          className="fixed inset-0 bg-black/50 flex items-start justify-center z-50 p-4 pt-20"
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              setShowSearch(false);
            }
          }}
        >
          <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-2xl w-full transition-colors">
            <div className="p-4 border-b border-gray-200 dark:border-gray-700">
              <div className="flex items-center gap-3">
                <Search size={20} className="text-gray-400 dark:text-gray-500" />
                <input
                  type="text"
                  placeholder="Search by event title or contact name..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="flex-1 bg-transparent border-none outline-none text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500"
                  autoFocus
                />
                <button
                  onClick={() => {
                    setShowSearch(false);
                    setSearchQuery('');
                  }}
                  className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full dark:text-white"
                >
                  <X size={20} />
                </button>
              </div>
            </div>

            <div className="max-h-[60vh] overflow-y-auto p-4">
              {searchQuery.trim() ? (
                getFilteredEvents().length > 0 ? (
                  <div className="space-y-2">
                    {getFilteredEvents().map(event => {
                      const contact = event.contactId ? mockContacts.find(c => c.id === event.contactId) : null;
                      return (
                        <button
                          key={event.id}
                          onClick={() => {
                            setShowSearch(false);
                            onEventClick(event);
                          }}
                          className="w-full bg-gray-50 dark:bg-gray-700/50 rounded-lg p-4 hover:bg-gray-100 dark:hover:bg-gray-700 transition-all text-left border border-transparent hover:border-purple-400"
                        >
                          <div className="flex items-start gap-3">
                            <div
                              className="w-1 h-full rounded-full flex-shrink-0 self-stretch"
                              style={{ backgroundColor: getEventTypeColor(event.type) }}
                            />
                            <div className="flex-1 min-w-0">
                              <div className="flex items-start justify-between gap-2 mb-1">
                                <h5 className="font-medium dark:text-white">{event.title}</h5>
                                {contact && (
                                  <span className="text-2xl flex-shrink-0">{contact.avatar}</span>
                                )}
                              </div>
                              <div className="flex items-center gap-2 flex-wrap text-sm text-gray-600 dark:text-gray-400">
                                <span>{formatDateHeader(event.date)}</span>
                                {!event.isAllDay && event.startTime && event.endTime && (
                                  <>
                                    <span>•</span>
                                    <span>{formatTime(event.startTime)} - {formatTime(event.endTime)}</span>
                                  </>
                                )}
                                {contact && (
                                  <>
                                    <span>•</span>
                                    <span>with {contact.name}</span>
                                  </>
                                )}
                              </div>
                            </div>
                          </div>
                        </button>
                      );
                    })}
                  </div>
                ) : (
                  <div className="text-center py-12">
                    <p className="text-gray-500 dark:text-gray-400">No events found for "{searchQuery}"</p>
                  </div>
                )
              ) : (
                <div className="text-center py-12">
                  <Search size={48} className="mx-auto text-gray-300 dark:text-gray-600 mb-3" />
                  <p className="text-gray-500 dark:text-gray-400">Start typing to search events</p>
                  <p className="text-sm text-gray-400 dark:text-gray-500 mt-1">Search by title or contact name</p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Month Picker Modal */}
      {showMonthPicker && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-800 rounded-2xl max-w-md w-full p-6 transition-colors">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-lg font-semibold dark:text-white">Select Month</h3>
              <button
                onClick={() => setShowMonthPicker(false)}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-full dark:text-white"
              >
                <X size={20} />
              </button>
            </div>

            <div className="flex items-center justify-between mb-6">
              <button
                onClick={() => setCurrentDate(new Date(currentDate.getFullYear() - 1, currentDate.getMonth(), 1))}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg dark:text-white transition-colors"
              >
                <ChevronLeft size={20} />
              </button>
              <div className="font-semibold dark:text-white text-xl min-w-[100px] text-center">
                {currentDate.getFullYear()}
              </div>
              <button
                onClick={() => setCurrentDate(new Date(currentDate.getFullYear() + 1, currentDate.getMonth(), 1))}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg dark:text-white transition-colors"
              >
                <ChevronRight size={20} />
              </button>
            </div>

            <div className="grid grid-cols-3 gap-2">
              {monthNames.map((month, index) => (
                <button
                  key={month}
                  onClick={() => {
                    setCurrentDate(new Date(currentDate.getFullYear(), index, 1));
                    setShowMonthPicker(false);
                  }}
                  className={`p-3 rounded-lg font-medium transition-colors ${
                    currentDate.getMonth() === index
                      ? 'text-white'
                      : 'hover:bg-gray-100 dark:hover:bg-gray-700 dark:text-white'
                  }`}
                  style={currentDate.getMonth() === index ? { backgroundColor: '#7C34ED' } : {}}
                >
                  {month.slice(0, 3)}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}