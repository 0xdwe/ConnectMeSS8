import { useState, useRef } from 'react';
import { ArrowLeft, Send, Image as ImageIcon, X, Sparkles } from 'lucide-react';
import { Contact } from './mock-data';

interface Message {
  id: string;
  type: 'user' | 'ai';
  content: string;
  image?: string;
  timestamp: Date;
}

interface AIUpdateChatProps {
  contact: Contact;
  onBack: () => void;
  onUpdateComplete: (updates: { summary: string; aiSummary: string; topicRecommendations: string[] }) => void;
}

export function AIUpdateChat({ contact, onBack, onUpdateComplete }: AIUpdateChatProps) {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '1',
      type: 'ai',
      content: `Hi! I'm here to help you update your connection with ${contact.name}. You can tell me about your recent interaction, share photos, or just chat about what happened. I'll automatically update the connection details for you!`,
      timestamp: new Date()
    }
  ]);
  const [inputText, setInputText] = useState('');
  const [selectedImage, setSelectedImage] = useState<string>('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        setSelectedImage(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSend = () => {
    if (!inputText.trim() && !selectedImage) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      type: 'user',
      content: inputText,
      image: selectedImage,
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);

    // Simulate AI response
    setTimeout(() => {
      const aiResponse = generateAIResponse(inputText, selectedImage);
      const aiMessage: Message = {
        id: (Date.now() + 1).toString(),
        type: 'ai',
        content: aiResponse,
        timestamp: new Date()
      };
      setMessages(prev => [...prev, aiMessage]);
    }, 1000);

    setInputText('');
    setSelectedImage('');
  };

  const generateAIResponse = (text: string, hasImage: boolean) => {
    const responses = [
      `Great! I've noted that you ${text.toLowerCase()}. I'm updating the interaction log and adjusting the bond score based on this positive engagement.`,
      `Thanks for sharing! This interaction shows strong connection. I've recorded this in the activity log and updated the last contact date.`,
      `Wonderful! ${hasImage ? 'The photo captures a great moment together. ' : ''}I'm updating ${contact.name}'s profile with this latest interaction.`,
      `Got it! I've added this to the activity history. Your bond score with ${contact.name} has increased based on this meaningful interaction.`
    ];
    return responses[Math.floor(Math.random() * responses.length)];
  };

  const handleComplete = () => {
    const userMessages = messages.filter(m => m.type === 'user');
    const updateSummary = userMessages.map(m => m.content).join(', ');

    // Generate AI summary based on conversation
    const aiSummary = generatePersonSummary(userMessages, contact);

    // Generate topic recommendations
    const topicRecommendations = generateTopicRecommendations(userMessages, contact);

    onUpdateComplete({
      summary: updateSummary,
      aiSummary,
      topicRecommendations
    });
  };

  const generatePersonSummary = (userMessages: Message[], contact: Contact) => {
    if (userMessages.length === 0) return contact.aiSummary || '';

    // Analyze the conversation to create a summary
    const conversationText = userMessages.map(m => m.content.toLowerCase()).join(' ');
    const yearsSince = new Date().getFullYear() - new Date(contact.knownSince).getFullYear();

    // Detect themes in the conversation
    const themes = [];
    if (conversationText.includes('work') || conversationText.includes('job') || conversationText.includes('career')) {
      themes.push('professional development');
    }
    if (conversationText.includes('family') || conversationText.includes('kids') || conversationText.includes('parent')) {
      themes.push('family matters');
    }
    if (conversationText.includes('travel') || conversationText.includes('vacation') || conversationText.includes('trip')) {
      themes.push('travel experiences');
    }
    if (conversationText.includes('hobby') || conversationText.includes('interest') || conversationText.includes('passion')) {
      themes.push('personal hobbies');
    }

    const themeText = themes.length > 0 ? ` Recent conversations show interest in ${themes.join(', ')}.` : '';

    return `${contact.name} is a ${contact.category.toLowerCase()} connection you've known for ${yearsSince} years. Your relationship shows ${contact.bondScore > 80 ? 'strong' : contact.bondScore > 60 ? 'good' : 'moderate'} engagement through ${contact.topChannels.join(', ')}.${themeText} Bond score: ${contact.bondScore}.`;
  };

  const generateTopicRecommendations = (userMessages: Message[], contact: Contact) => {
    if (userMessages.length === 0) return contact.topicRecommendations || [];

    const conversationText = userMessages.map(m => m.content.toLowerCase()).join(' ');
    const recommendations = new Set<string>();

    // Add recommendations based on conversation content
    if (conversationText.includes('work') || conversationText.includes('job')) {
      recommendations.add('Career updates');
      recommendations.add('Work-life balance');
    }
    if (conversationText.includes('family')) {
      recommendations.add('Family activities');
      recommendations.add('Family updates');
    }
    if (conversationText.includes('travel') || conversationText.includes('vacation')) {
      recommendations.add('Travel plans');
      recommendations.add('Destination ideas');
    }
    if (conversationText.includes('hobby') || conversationText.includes('interest')) {
      recommendations.add('Shared hobbies');
      recommendations.add('New interests');
    }
    if (conversationText.includes('coffee') || conversationText.includes('lunch') || conversationText.includes('dinner')) {
      recommendations.add('Meal plans');
      recommendations.add('Restaurant recommendations');
    }

    // Add category-specific recommendations
    if (contact.category === 'Work') {
      recommendations.add('Project collaboration');
    } else if (contact.category === 'Friends') {
      recommendations.add('Weekend plans');
      recommendations.add('Catch-up ideas');
    } else if (contact.category === 'Family') {
      recommendations.add('Family gatherings');
    }

    // Always include a general recommendation
    recommendations.add('Recent life updates');

    return Array.from(recommendations).slice(0, 6);
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 flex flex-col transition-colors">
      <div className="text-white p-4 flex items-center justify-between" style={{ backgroundColor: '#7C34ED' }}>
        <div className="flex items-center gap-3">
          <button onClick={onBack} className="hover:opacity-80">
            <ArrowLeft size={24} />
          </button>
          <div>
            <div className="flex items-center gap-2">
              <Sparkles size={18} />
              <h1 className="font-semibold">AI Update</h1>
            </div>
            <p className="text-sm opacity-90">Chat with {contact.name}</p>
          </div>
        </div>
        <button
          onClick={handleComplete}
          className="px-4 py-2 bg-white rounded-lg text-sm font-medium hover:opacity-90 transition-opacity"
          style={{ color: '#C5A8E8' }}
        >
          Done
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map(message => (
          <div
            key={message.id}
            className={`flex ${message.type === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div
              className={`max-w-[80%] rounded-2xl p-3 ${
                message.type === 'user'
                  ? 'text-white'
                  : 'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700'
              }`}
              style={{
                backgroundColor: message.type === 'user' ? '#C5A8E8' : undefined
              }}
            >
              {message.type === 'ai' && (
                <div className="flex items-center gap-2 mb-2">
                  <Sparkles size={16} style={{ color: '#C5A8E8' }} />
                  <span className="text-xs font-medium" style={{ color: '#C5A8E8' }}>
                    AI Assistant
                  </span>
                </div>
              )}
              {message.image && (
                <img
                  src={message.image}
                  alt="Shared"
                  className="rounded-lg mb-2 max-h-48 object-cover"
                />
              )}
              <p className={`text-sm ${message.type === 'ai' ? 'dark:text-white' : ''}`}>{message.content}</p>
              <span
                className={`text-xs mt-1 block ${
                  message.type === 'user' ? 'text-white/70' : 'text-gray-500'
                }`}
              >
                {message.timestamp.toLocaleTimeString([], {
                  hour: '2-digit',
                  minute: '2-digit'
                })}
              </span>
            </div>
          </div>
        ))}
      </div>

      <div className="p-4 bg-white dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 transition-colors">
        {selectedImage && (
          <div className="mb-2 relative inline-block">
            <img
              src={selectedImage}
              alt="Selected"
              className="h-20 rounded-lg object-cover"
            />
            <button
              onClick={() => setSelectedImage('')}
              className="absolute -top-2 -right-2 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center hover:bg-red-600"
            >
              <X size={14} />
            </button>
          </div>
        )}
        <div className="flex items-center gap-2">
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={handleImageSelect}
          />
          <button
            onClick={() => fileInputRef.current?.click()}
            className="p-3 rounded-full hover:bg-gray-100 transition-colors"
            style={{ color: '#C5A8E8' }}
          >
            <ImageIcon size={24} />
          </button>
          <input
            type="text"
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleSend()}
            placeholder="Tell me about your interaction..."
            className="flex-1 px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-full focus:outline-none bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500"
            onFocus={(e) => {
              e.currentTarget.style.borderColor = '#C5A8E8';
              e.currentTarget.style.boxShadow = '0 0 0 2px rgba(0, 128, 128, 0.2)';
            }}
            onBlur={(e) => {
              e.currentTarget.style.borderColor = '';
              e.currentTarget.style.boxShadow = '';
            }}
          />
          <button
            onClick={handleSend}
            disabled={!inputText.trim() && !selectedImage}
            className="p-3 rounded-full text-white transition-opacity disabled:opacity-50"
            style={{ backgroundColor: '#7C34ED' }}
          >
            <Send size={24} />
          </button>
        </div>
      </div>
    </div>
  );
}
