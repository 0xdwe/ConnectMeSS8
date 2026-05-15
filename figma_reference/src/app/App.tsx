import { useState } from 'react';
import { TopHeader } from './components/TopHeader';
import { BottomNav } from './components/BottomNav';
import { HomeTab } from './components/HomeTab';
import { PlannerTab } from './components/PlannerTab';
import { PeopleTab } from './components/PeopleTab';
import { SettingsTab } from './components/SettingsTab';
import { ProfileView } from './components/ProfileView';
import { ContactDashboard } from './components/ContactDashboard';
import { RecommendationsView } from './components/RecommendationsView';
import { AddConnectionModal } from './components/AddConnectionModal';
import { SelectContactModal } from './components/SelectContactModal';
import { EditConnectionModal } from './components/EditConnectionModal';
import { SharedActivityModal } from './components/SharedActivityModal';
import { AddEventModal } from './components/AddEventModal';
import { EventDetailModal } from './components/EventDetailModal';
import { AuthScreen } from './components/AuthScreen';
import { AIUpdateChat } from './components/AIUpdateChat';
import { ThemeModal } from './components/ThemeModal';
import { ManageCategoriesModal } from './components/ManageCategoriesModal';
import { ManageEventTypesModal } from './components/ManageEventTypesModal';
import { EditUserProfileModal } from './components/EditUserProfileModal';
import { ThemeProvider } from './components/ThemeContext';
import { mockUser, mockContacts, mockEvents, mockTasks, mockRecommendations, Contact, Event } from './components/mock-data';
import { toast, Toaster } from 'sonner';

type ViewType = 'home' | 'planner' | 'people' | 'settings' | 'profile' | 'contact' | 'recommendations' | 'ai-update';

function AppContent() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [activeTab, setActiveTab] = useState<string>('home');
  const [currentView, setCurrentView] = useState<ViewType>('home');
  const [selectedContactId, setSelectedContactId] = useState<string | null>(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const [showSelectContactModal, setShowSelectContactModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showSharedActivityModal, setShowSharedActivityModal] = useState(false);
  const [showThemeModal, setShowThemeModal] = useState(false);
  const [showManageCategoriesModal, setShowManageCategoriesModal] = useState(false);
  const [showManageEventTypesModal, setShowManageEventTypesModal] = useState(false);
  const [showAddEventModal, setShowAddEventModal] = useState(false);
  const [showEventDetailModal, setShowEventDetailModal] = useState(false);
  const [showEditUserProfileModal, setShowEditUserProfileModal] = useState(false);
  const [selectedEventDate, setSelectedEventDate] = useState<string>('');
  const [selectedEvent, setSelectedEvent] = useState<Event | null>(null);
  const [editingContact, setEditingContact] = useState<Contact | null>(null);
  const [categories, setCategories] = useState<string[]>(['Family', 'Friends', 'High School', 'College', 'Work', 'Other']);
  const [eventTypes, setEventTypes] = useState<string[]>(['Plan', 'Reminder', 'Birthday', 'Meeting', 'Call', 'Dinner', 'Coffee']);
  const [events, setEvents] = useState<(Event & { isRecurring?: boolean; recurrencePattern?: string })[]>(mockEvents);
  const [deletedEvent, setDeletedEvent] = useState<(Event & { isRecurring?: boolean; recurrencePattern?: string }) | null>(null);
  const [contacts, setContacts] = useState<Contact[]>(mockContacts);
  const [user, setUser] = useState(mockUser);

  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    setCurrentView(tab as ViewType);
  };

  const handleProfileClick = () => {
    setCurrentView('profile');
  };

  const handleEditUserProfile = () => {
    setShowEditUserProfileModal(true);
  };

  const handleSaveUserProfile = (updates: { name: string; email: string; avatar: string }) => {
    setUser(prev => ({ ...prev, ...updates }));
    toast.success('Profile updated successfully!');
  };

  const handleContactClick = (contactId: string) => {
    setSelectedContactId(contactId);
    setCurrentView('contact');
  };

  const handleBackFromContact = () => {
    setCurrentView('people');
    setActiveTab('people');
  };

  const handleBackFromProfile = () => {
    setCurrentView(activeTab as ViewType);
  };

  const handleViewRecommendations = () => {
    setCurrentView('recommendations');
  };

  const handleBackFromRecommendations = () => {
    setCurrentView('home');
    setActiveTab('home');
  };

  const handleNavigateToContactFromRec = (contactId: string) => {
    setSelectedContactId(contactId);
    setCurrentView('contact');
  };

  const handleEventClick = (event: Event) => {
    setSelectedEvent(event);
    setSelectedEventDate(event.date);
    setShowAddEventModal(true);
  };

  const handleAddConnection = () => {
    setShowAddModal(true);
  };

  const handleUpdateConnection = () => {
    setShowSelectContactModal(true);
  };

  const handleSelectContactForUpdate = (contact: Contact) => {
    setSelectedContactId(contact.id);
    setCurrentView('ai-update');
  };

  const handleSaveConnection = (data: { name: string; email: string; category: string }) => {
    toast.success(`Added ${data.name} to your connections!`);
  };

  const handleLogin = (email: string, password: string) => {
    toast.success('Welcome to Connect Me!');
    setIsLoggedIn(true);
  };

  const handleEditContact = (contact: Contact) => {
    setEditingContact(contact);
    setShowEditModal(true);
  };

  const handleSaveEditContact = (contactId: string, updates: Partial<Contact>) => {
    toast.success('Connection updated successfully!');
  };

  const handleShareActivity = (contactId: string) => {
    setSelectedContactId(contactId);
    setShowSharedActivityModal(true);
  };

  const handleSaveSharedActivity = (contactId: string, type: 'photo' | 'note', content: string) => {
    const contact = contacts.find(c => c.id === contactId);
    toast.success(`Shared ${type} with ${contact?.name}!`);
  };

  const handleAIUpdate = (contact: Contact) => {
    setSelectedContactId(contact.id);
    setCurrentView('ai-update');
  };

  const handleBackFromAIUpdate = () => {
    setCurrentView('contact');
  };

  const handleAIUpdateComplete = (updates: { summary: string; aiSummary: string; topicRecommendations: string[] }) => {
    if (selectedContactId) {
      setContacts(prev => prev.map(contact =>
        contact.id === selectedContactId
          ? { ...contact, aiSummary: updates.aiSummary, topicRecommendations: updates.topicRecommendations }
          : contact
      ));
    }
    toast.success('Connection updated successfully with AI!', {
      icon: '✨'
    });
    setCurrentView('contact');
  };

  const handleDeleteConnection = (contactId: string) => {
    const contact = contacts.find(c => c.id === contactId);
    toast.success(`${contact?.name} has been removed from your connections`);
    setSelectedContactId(null);
    setCurrentView('people');
    setActiveTab('people');
  };

  const handleAddEventClick = (date: string) => {
    setSelectedEventDate(date);
    setShowAddEventModal(true);
  };

  const handleSaveEvent = (event: {
    id?: string;
    date: string;
    title: string;
    contactId?: string;
    type: string;
    isAllDay?: boolean;
    startTime?: string;
    endTime?: string;
    isRecurring?: boolean;
    recurrencePattern?: 'daily' | 'weekly' | 'monthly' | 'yearly';
  }) => {
    if (event.id) {
      // Update existing event
      setEvents(prev => prev.map(e => e.id === event.id ? { ...event } as any : e));
      const recurringText = event.isRecurring ? ` (${event.recurrencePattern})` : '';
      toast.success(`Event "${event.title}"${recurringText} updated successfully!`);
    } else {
      // Create new event
      const newEvent = {
        id: `e${Date.now()}`,
        ...event
      };
      setEvents(prev => [...prev, newEvent]);
      const recurringText = event.isRecurring ? ` (${event.recurrencePattern})` : '';
      toast.success(`Event "${event.title}"${recurringText} added successfully!`);
    }
    setSelectedEvent(null);
  };

  const handleDeleteEvent = (eventId: string) => {
    const eventToDelete = events.find(e => e.id === eventId);
    if (eventToDelete) {
      setDeletedEvent(eventToDelete);
      setEvents(prev => prev.filter(e => e.id !== eventId));
      toast.success('Event deleted', {
        action: {
          label: 'Undo',
          onClick: () => handleUndoDelete(eventToDelete)
        },
        duration: 5000
      });
    }
  };

  const handleUndoDelete = (event: Event & { isRecurring?: boolean; recurrencePattern?: string }) => {
    setEvents(prev => [...prev, event].sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()));
    setDeletedEvent(null);
    toast.success('Event restored');
  };

  const handleSaveCategories = (newCategories: string[]) => {
    setCategories(newCategories);
    toast.success('Categories updated successfully!');
  };

  const handleSaveEventTypes = (newEventTypes: string[]) => {
    setEventTypes(newEventTypes);
    toast.success('Event types updated successfully!');
  };

  if (!isLoggedIn) {
    return <AuthScreen onLogin={handleLogin} />;
  }

  const renderContent = () => {
    if (currentView === 'profile') {
      return <ProfileView user={user} onBack={handleBackFromProfile} />;
    }

    if (currentView === 'contact' && selectedContactId) {
      const contact = contacts.find(c => c.id === selectedContactId);
      const recommendation = mockRecommendations.find(r => r.contactId === selectedContactId);
      if (contact) {
        return (
          <ContactDashboard
            contact={contact}
            onBack={handleBackFromContact}
            onEdit={handleEditContact}
            onShareActivity={handleShareActivity}
            onAIUpdate={handleAIUpdate}
            scoreGain={recommendation?.scoreGain}
          />
        );
      }
    }

    if (currentView === 'ai-update' && selectedContactId) {
      const contact = contacts.find(c => c.id === selectedContactId);
      if (contact) {
        return (
          <AIUpdateChat
            contact={contact}
            onBack={handleBackFromAIUpdate}
            onUpdateComplete={handleAIUpdateComplete}
          />
        );
      }
    }

    if (currentView === 'recommendations') {
      return (
        <RecommendationsView
          onBack={handleBackFromRecommendations}
          onNavigateToContact={handleNavigateToContactFromRec}
        />
      );
    }

    switch (activeTab) {
      case 'home':
        return (
          <HomeTab
            connectionScore={mockUser.connectionScore}
            onAddConnection={handleAddConnection}
            onUpdateConnection={handleUpdateConnection}
            onViewRecommendations={handleViewRecommendations}
            onNavigateToContact={handleNavigateToContactFromRec}
          />
        );
      case 'planner':
        return <PlannerTab events={events} onEventClick={handleEventClick} onAddEvent={handleAddEventClick} />;
      case 'people':
        return <PeopleTab contacts={contacts} onContactClick={handleContactClick} availableCategories={categories} />;
      case 'settings':
        return (
          <SettingsTab
            onEditProfile={handleEditUserProfile}
            onThemeClick={() => setShowThemeModal(true)}
            onManageCategories={() => setShowManageCategoriesModal(true)}
            onManageEventTypes={() => setShowManageEventTypesModal(true)}
          />
        );
      default:
        return null;
    }
  };

  const showHeaderAndNav = !['profile', 'contact', 'recommendations', 'ai-update'].includes(currentView);

  return (
    <div className="min-h-screen bg-background transition-colors">
      <Toaster position="top-center" richColors />

      {showHeaderAndNav && (
        <TopHeader
          userName={user.name}
          userAvatar={user.avatar}
          onProfileClick={handleProfileClick}
        />
      )}

      <main className={showHeaderAndNav ? 'pt-16 pb-16' : ''}>
        {renderContent()}
      </main>

      {showHeaderAndNav && (
        <BottomNav
          activeTab={activeTab}
          onTabChange={handleTabChange}
          onAddConnection={handleAddConnection}
          onUpdateConnection={handleUpdateConnection}
        />
      )}

      {showAddModal && (
        <AddConnectionModal
          onClose={() => setShowAddModal(false)}
          onSave={handleSaveConnection}
          availableCategories={categories}
        />
      )}

      {showSelectContactModal && (
        <SelectContactModal
          onClose={() => setShowSelectContactModal(false)}
          onSelectContact={handleSelectContactForUpdate}
          contacts={contacts}
        />
      )}

      {showEditModal && editingContact && (
        <EditConnectionModal
          contact={editingContact}
          onClose={() => {
            setShowEditModal(false);
            setEditingContact(null);
          }}
          onSave={handleSaveEditContact}
          onDelete={(contactId) => {
            handleDeleteConnection(contactId);
            setShowEditModal(false);
            setEditingContact(null);
          }}
          availableCategories={categories}
        />
      )}

      {showSharedActivityModal && (
        <SharedActivityModal
          onClose={() => setShowSharedActivityModal(false)}
          onSave={handleSaveSharedActivity}
        />
      )}

      {showThemeModal && (
        <ThemeModal onClose={() => setShowThemeModal(false)} />
      )}

      {showEditUserProfileModal && (
        <EditUserProfileModal
          user={user}
          onClose={() => setShowEditUserProfileModal(false)}
          onSave={handleSaveUserProfile}
        />
      )}

      {showAddEventModal && (
        <AddEventModal
          selectedDate={selectedEventDate}
          onClose={() => {
            setShowAddEventModal(false);
            setSelectedEvent(null);
          }}
          onSave={handleSaveEvent}
          event={selectedEvent || undefined}
          onDelete={handleDeleteEvent}
          availableEventTypes={eventTypes}
        />
      )}

      {showManageCategoriesModal && (
        <ManageCategoriesModal
          categories={categories}
          onClose={() => setShowManageCategoriesModal(false)}
          onSave={handleSaveCategories}
        />
      )}

      {showManageEventTypesModal && (
        <ManageEventTypesModal
          eventTypes={eventTypes}
          onClose={() => setShowManageEventTypesModal(false)}
          onSave={handleSaveEventTypes}
        />
      )}

      {showEventDetailModal && selectedEvent && (
        <EventDetailModal
          event={selectedEvent}
          onClose={() => {
            setShowEventDetailModal(false);
            setSelectedEvent(null);
          }}
          onDelete={handleDeleteEvent}
          onViewContact={(contactId) => {
            handleContactClick(contactId);
            setShowEventDetailModal(false);
          }}
        />
      )}
    </div>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <AppContent />
    </ThemeProvider>
  );
}