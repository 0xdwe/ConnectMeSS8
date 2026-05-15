import { ArrowLeft, Mail, Calendar, MessageCircle, TrendingUp, Lightbulb, Edit, Share2, Sparkles, Award, ChevronDown, ChevronUp, User, MessageSquare, TrendingDown, BarChart3, Minus } from 'lucide-react';
import { Contact } from './mock-data';
import { useState } from 'react';
import { toast } from 'sonner';

interface ContactDashboardProps {
  contact: Contact;
  onBack: () => void;
  onEdit: (contact: Contact) => void;
  onShareActivity: (contactId: string) => void;
  onAIUpdate: (contact: Contact) => void;
  scoreGain?: number;
}

export function ContactDashboard({ contact, onBack, onEdit, onShareActivity, onAIUpdate, scoreGain }: ContactDashboardProps) {
  const yearsSince = new Date().getFullYear() - new Date(contact.knownSince).getFullYear();
  const maxActivity = Math.max(...contact.interactionFrequency);
  const [showDetails, setShowDetails] = useState(false);
  const [showActivityLog, setShowActivityLog] = useState(false);
  const [showAISummary, setShowAISummary] = useState(true);
  const [selectedTopic, setSelectedTopic] = useState<string | null>(null);
  const [hoveredMonth, setHoveredMonth] = useState<number | null>(null);

  // Calculate bond score trend
  const calculateScoreTrend = () => {
    const recentInteractions = contact.interactionFrequency.slice(-3).reduce((a, b) => a + b, 0);
    const previousInteractions = contact.interactionFrequency.slice(-6, -3).reduce((a, b) => a + b, 0);
    const daysSinceLastContact = Math.floor((new Date().getTime() - new Date(contact.lastContact).getTime()) / (1000 * 60 * 60 * 24));

    if (recentInteractions > previousInteractions && daysSinceLastContact < 7) {
      return { status: 'up', text: 'Trending Up', color: '#10B981' }; // green
    } else if (recentInteractions < previousInteractions || daysSinceLastContact > 14) {
      return { status: 'down', text: 'Trending Down', color: '#EF4444' }; // red
    } else {
      return { status: 'stable', text: 'Stable', color: '#F59E0B' }; // amber
    }
  };

  const scoreTrend = calculateScoreTrend();

  const getMonthName = (index: number) => {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[index];
  };

  const handleSocialShare = () => {
    // Create a shareable message about the connection
    const shareText = `I've been connected with ${contact.name} for ${yearsSince} years! Our bond score: ${contact.bondScore} 🎉`;

    // Use Web Share API if available (works on mobile for Instagram, etc.)
    if (navigator.share) {
      navigator.share({
        title: 'My Connection',
        text: shareText,
      }).catch((error) => console.log('Error sharing:', error));
    } else {
      // Fallback: copy to clipboard
      navigator.clipboard.writeText(shareText);
      alert('Connection details copied to clipboard! You can now share to Instagram, Threads, or any social media.');
    }
  };

  const generateTopicElaboration = (topic: string): JSX.Element => {
    // Find related activity log entries
    const relatedActivities = contact.activityLog.filter(log => {
      const logText = `${log.type} ${log.notes}`.toLowerCase();
      const topicLower = topic.toLowerCase();

      // Comprehensive keyword matching
      if (topicLower.includes('weekend') && (logText.includes('weekend') || logText.includes('plans') || logText.includes('hiking'))) return true;
      if (topicLower.includes('coffee') && (logText.includes('coffee') || logText.includes('cafe') || logText.includes('brunch'))) return true;
      if (topicLower.includes('career') && (logText.includes('career') || logText.includes('job') || logText.includes('work'))) return true;
      if (topicLower.includes('family') && (logText.includes('family') || logText.includes('kids') || logText.includes('reunion'))) return true;
      if (topicLower.includes('travel') && (logText.includes('travel') || logText.includes('vacation') || logText.includes('trip') || logText.includes('bali') || logText.includes('europe') || logText.includes('thailand'))) return true;
      if (topicLower.includes('project') && (logText.includes('project') || logText.includes('sprint') || logText.includes('deliverable'))) return true;
      if (topicLower.includes('college') && (logText.includes('college') || logText.includes('reunion'))) return true;
      if (topicLower.includes('high school') && (logText.includes('high school') || logText.includes('basketball'))) return true;
      if (topicLower.includes('funny') && (logText.includes('funny') || logText.includes('meme'))) return true;
      if (topicLower.includes('local') && (logText.includes('downtown') || logText.includes('main st'))) return true;

      return false;
    });

    // Generate contextual starters based on topic
    const getContextualInfo = () => {
      switch (topic) {
        case 'Weekend plans':
          return {
            starter: 'Hey! Any fun plans for the weekend?',
            context: 'Downtown has a new food festival this Saturday 2-8pm',
            relatedNews: 'Local farmer\'s market is back in season'
          };
        case 'Coffee shop recommendations':
          return {
            starter: 'I discovered this amazing coffee spot called Brew Haven - have you been?',
            context: 'They have a new oat milk latte that\'s incredible',
            relatedNews: 'Blue Bottle just opened on Main Street'
          };
        case 'Funny stories':
          return {
            starter: 'You won\'t believe what happened to me yesterday...',
            context: 'That viral TikTok about coffee shop mishaps reminded me of us',
            relatedNews: 'New comedy special "Everyday Chaos" trending on Netflix'
          };
        case 'Local events':
          return {
            starter: 'There\'s a street fair happening downtown this Saturday!',
            context: 'Live music, food trucks, and local vendors 12-6pm',
            relatedNews: 'City approved 15 new events for summer season'
          };
        case 'Career updates':
          return {
            starter: 'How are things going at work lately?',
            context: 'Tech industry seeing 15% growth in AI roles this quarter',
            relatedNews: 'LinkedIn reports increased remote job postings'
          };
        case 'Work-life balance':
          return {
            starter: 'How have you been managing work and personal time?',
            context: '4-day work week trials showing 40% productivity increase',
            relatedNews: 'New study: 62% of workers prioritize flexibility over salary'
          };
        case 'Career goals':
          return {
            starter: 'What are you working towards career-wise these days?',
            context: 'Many professionals are pivoting to AI/ML specializations',
            relatedNews: 'Q2 2026 job market shows demand for hybrid skills'
          };
        case 'High school memories':
          return {
            starter: 'Remember when we used to hang out at that pizza place after school?',
            context: 'Class of 2010 reunion being planned for August',
            relatedNews: 'Old high school just renovated the gym we played in'
          };
        case 'Industry trends':
          return {
            starter: 'Have you been following the latest developments in your field?',
            context: 'AI integration reshaping most industries in 2026',
            relatedNews: 'Forbes: Top 10 emerging tech trends to watch'
          };
        case 'Personal hobbies':
          return {
            starter: 'What have you been doing for fun lately?',
            context: 'Spring is perfect for outdoor activities',
            relatedNews: 'New community centers offering free hobby classes'
          };
        case 'Family updates':
          return {
            starter: 'How\'s the family doing?',
            context: 'School spring break starts next week',
            relatedNews: 'Mother\'s Day coming up May 11th'
          };
        case 'Family activities':
          return {
            starter: 'Done anything fun with the family recently?',
            context: 'New family-friendly park opened with splash pad',
            relatedNews: 'Free outdoor movie nights starting in Memorial Park'
          };
        case 'Family gatherings':
          return {
            starter: 'Any family get-togethers coming up?',
            context: 'Memorial Day weekend perfect for BBQs (May 25-26)',
            relatedNews: 'Summer reunion season starting - venues booking fast'
          };
        case 'Travel plans':
          return {
            starter: 'Got any trips on the horizon?',
            context: 'Summer flight prices dropping 20% for early bookers',
            relatedNews: 'Japan reopened visa-free travel for tourism'
          };
        case 'Destination ideas':
          return {
            starter: 'Where\'s on your travel bucket list?',
            context: 'Iceland seeing 30% tourism increase - Northern Lights season',
            relatedNews: 'Portugal named #1 destination for digital nomads 2026'
          };
        case 'Travel stories':
          return {
            starter: 'Tell me about your recent trip!',
            context: 'Travel vlogs trending on YouTube - people love authentic stories',
            relatedNews: 'National Geographic\'s photo contest accepting submissions'
          };
        case 'Shared hobbies':
          return {
            starter: 'We should get back into [hobby] together!',
            context: 'Local clubs meeting weekly at community center',
            relatedNews: 'Meetup.com shows 45% increase in hobby groups'
          };
        case 'New interests':
          return {
            starter: 'Picked up any new hobbies or interests?',
            context: 'Pottery, pickleball, and sourdough baking trending in 2026',
            relatedNews: 'Skillshare offering free trials for May'
          };
        case 'Meal plans':
          return {
            starter: 'Want to grab lunch/dinner sometime soon?',
            context: 'Restaurant week happening May 10-17 with prix fixe menus',
            relatedNews: 'That new fusion place on 5th Ave getting rave reviews'
          };
        case 'Restaurant recommendations':
          return {
            starter: 'I found this incredible restaurant - we should try it!',
            context: 'Michelin released 2026 guide - 8 new local stars',
            relatedNews: 'Food Network featuring local chef on next episode'
          };
        case 'Project collaboration':
          return {
            starter: 'I have an idea for a project we could work on together',
            context: 'Hackathons and collaboration events happening monthly',
            relatedNews: 'GitHub Copilot Workspace making team coding easier'
          };
        case 'Project updates':
          return {
            starter: 'How\'s that project coming along?',
            context: 'Q2 deadlines approaching end of June',
            relatedNews: 'New project management tools trending: Linear, Notion AI'
          };
        case 'Catch-up ideas':
          return {
            starter: 'We\'re overdue for a proper catch-up!',
            context: 'Virtual happy hours or in-person coffee both work great',
            relatedNews: 'Studies show even 30-min catch-ups boost relationship quality'
          };
        case 'Recent life updates':
          return {
            starter: 'What\'s new with you? I feel like we haven\'t talked in forever!',
            context: `It\'s been ${Math.floor((new Date().getTime() - new Date(contact.lastContact).getTime()) / (1000 * 60 * 60 * 24))} days since your last chat`,
            relatedNews: null
          };
        case 'Video call plans':
          return {
            starter: 'Want to hop on a video call this week?',
            context: 'Zoom fatigue is real - keep it casual and short',
            relatedNews: 'FaceTime, Zoom, and Google Meet all adding AI features'
          };
        case 'College memories':
          return {
            starter: 'Remember those late nights in the library during finals?',
            context: 'Alumni weekend scheduled for October 2026',
            relatedNews: 'Campus just unveiled new student center renovation'
          };
        case 'Life updates':
          return {
            starter: 'So much has happened lately - let\'s catch up!',
            context: 'Q2 2026 bringing lots of changes for many people',
            relatedNews: null
          };
        case 'Daily life':
          return {
            starter: 'How has your week been going?',
            context: 'Sometimes the best conversations are about ordinary moments',
            relatedNews: null
          };
        case 'Future plans':
          return {
            starter: 'What are you looking forward to in the coming months?',
            context: 'Summer 2026 planning season - lots to look forward to',
            relatedNews: 'Goal-setting apps trending: Notion, Structured, Sunsama'
          };
        case 'Shared memories':
          return {
            starter: 'I was thinking about that time when we...',
            context: 'Nostalgia strengthens bonds - reminisce about good times',
            relatedNews: 'Facebook Memories feature getting AI-powered highlights'
          };
        case 'Career development':
          return {
            starter: 'What skills are you focusing on developing?',
            context: 'Coursera and Udemy offering May learning discounts',
            relatedNews: 'LinkedIn Learning added 500+ AI/tech courses'
          };
        case 'Coffee chat':
          return {
            starter: 'Coffee sometime this week? My treat!',
            context: 'That new cafe on Baker Street has amazing pastries',
            relatedNews: 'Studies: in-person meetings 3x more effective than email'
          };
        default:
          return {
            starter: `Let's talk about ${topic.toLowerCase()}`,
            context: 'Great conversation topic for reconnecting',
            relatedNews: null
          };
      }
    };

    const contextInfo = getContextualInfo();

    return (
      <div className="space-y-3">
        <div>
          <div className="text-xs font-semibold text-orange-700 dark:text-orange-300 mb-1">💬 Conversation Starter:</div>
          <div className="text-sm text-orange-900 dark:text-orange-100 bg-white/50 dark:bg-black/20 p-2 rounded">
            "{contextInfo.starter}"
          </div>
        </div>

        {relatedActivities.length > 0 && (
          <div>
            <div className="text-xs font-semibold text-orange-700 dark:text-orange-300 mb-1">📝 Past Conversations:</div>
            <div className="space-y-1">
              {relatedActivities.slice(0, 2).map((log, idx) => (
                <div key={idx} className="text-sm text-orange-900 dark:text-orange-100 bg-white/50 dark:bg-black/20 p-2 rounded">
                  <span className="font-medium">{log.date}:</span> {log.notes}
                </div>
              ))}
            </div>
          </div>
        )}

        <div>
          <div className="text-xs font-semibold text-orange-700 dark:text-orange-300 mb-1">🌐 Current Context:</div>
          <div className="text-sm text-orange-900 dark:text-orange-100 bg-white/50 dark:bg-black/20 p-2 rounded">
            {contextInfo.context}
          </div>
        </div>

        {contextInfo.relatedNews && (
          <div>
            <div className="text-xs font-semibold text-orange-700 dark:text-orange-300 mb-1">📰 Related News:</div>
            <div className="text-sm text-orange-900 dark:text-orange-100 bg-white/50 dark:bg-black/20 p-2 rounded">
              {contextInfo.relatedNews}
            </div>
          </div>
        )}
      </div>
    );
  };

  const handleTopicClick = (topic: string) => {
    if (selectedTopic === topic) {
      setSelectedTopic(null);
    } else {
      setSelectedTopic(topic);
    }
  };

  return (
    <div className="min-h-screen bg-background pb-24 transition-colors relative">
      <div className="text-white p-4" style={{ backgroundColor: '#7C34ED' }}>
        <div className="flex justify-between items-center mb-4">
          <button onClick={onBack} className="flex items-center gap-2 hover:opacity-80">
            <ArrowLeft size={20} />
            <span>Back</span>
          </button>
          <div className="flex items-center gap-2">
            <button
              onClick={handleSocialShare}
              className="flex items-center gap-2 px-3 py-2 bg-white/10 backdrop-blur-sm rounded-lg hover:bg-white/20 transition-all border border-white/20"
            >
              <Share2 size={18} />
            </button>
            <button
              onClick={() => onEdit(contact)}
              className="flex items-center gap-2 px-4 py-2 bg-white rounded-full hover:shadow-lg transition-all font-semibold"
              style={{ color: '#7C34ED' }}
            >
              <Edit size={18} />
              <span className="text-sm">Edit</span>
            </button>
          </div>
        </div>
        
        {/* Profile Section */}
        <div className="flex items-center gap-4 mb-4">
          <div className="w-20 h-20 rounded-full bg-white text-5xl flex items-center justify-center flex-shrink-0">
            {contact.avatar}
          </div>
          <div className="flex-1">
            <h1 className="text-2xl font-semibold mb-1">{contact.name}</h1>
            <p className="text-sm opacity-90 mb-1">{contact.category}</p>
            <p className="text-xs opacity-75">{contact.email}</p>
          </div>
        </div>

        {/* Bond Score - Prominent Display */}
        <div className="bg-white/10 backdrop-blur-sm rounded-xl p-4 border border-white/20">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm opacity-90 mb-1">Bond Score</div>
              <div className="flex items-center gap-3">
                <div className="text-5xl font-bold">{contact.bondScore}</div>
                <div className="flex items-center justify-center px-2 py-1 rounded-lg bg-white/20">
                  {scoreTrend.status === 'up' && <TrendingUp size={24} style={{ color: scoreTrend.color }} />}
                  {scoreTrend.status === 'down' && <TrendingDown size={24} style={{ color: scoreTrend.color }} />}
                  {scoreTrend.status === 'stable' && <Minus size={24} style={{ color: scoreTrend.color }} />}
                </div>
              </div>
            </div>
            <div className="text-right">
              <div className="text-xs opacity-75 mb-1">Known Since</div>
              <div className="text-2xl font-semibold">{yearsSince} years</div>
            </div>
          </div>
          <div className="mt-3 pt-3 border-t border-white/20 flex items-center gap-2 text-sm">
            <Calendar size={16} />
            <span className="opacity-90">Last contact: {contact.lastContact}</span>
          </div>
        </div>
      </div>

      <div className="p-4">
        {/* Score Gain Notification */}
        {scoreGain && (
          <div className="rounded-xl p-4 mb-4 shadow-lg text-white" style={{ background: 'linear-gradient(135deg, #FF7F50 0%, #FF6347 100%)' }}>
            <div className="flex items-center gap-3">
              <Award size={24} className="flex-shrink-0" />
              <div>
                <div className="font-semibold text-lg mb-1">Recommended Action!</div>
                <div className="text-sm opacity-95">
                  Gain <span className="font-bold text-xl">+{scoreGain}%</span> by reaching out
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Combined AI Insights Section */}
        <div className="bg-white rounded-3xl shadow-lg mb-4 transition-colors overflow-hidden">
          <button
            onClick={() => setShowAISummary(!showAISummary)}
            className="w-full p-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
          >
            <div className="flex items-center gap-2">
              <Sparkles size={18} style={{ color: '#7C34ED' }} />
              <h3 className="font-semibold dark:text-white">AI Insights</h3>
            </div>
            {showAISummary ? <ChevronUp size={20} className="text-gray-500" /> : <ChevronDown size={20} className="text-gray-500" />}
          </button>
          {showAISummary && (
            <div className="p-4 pt-0 border-t border-gray-100 dark:border-gray-700 space-y-4">
              {/* AI Tip/Recommendation */}
              <div className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-3">
                <div className="flex items-start gap-2">
                  <Lightbulb size={18} className="text-yellow-600 dark:text-yellow-400 flex-shrink-0 mt-0.5" />
                  <div>
                    <div className="text-sm font-medium text-yellow-900 dark:text-yellow-100 mb-1">Recommendation</div>
                    <p className="text-sm text-yellow-800 dark:text-yellow-200">{contact.aiTip}</p>
                  </div>
                </div>
              </div>

              {/* Person Summary */}
              {contact.aiSummary && (
                <div>
                  <div className="flex items-center gap-2 mb-2">
                    <User size={16} style={{ color: '#7C34ED' }} />
                    <h4 className="text-sm font-medium dark:text-white">Person Summary</h4>
                  </div>
                  <p className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">
                    {contact.aiSummary}
                  </p>
                </div>
              )}

              {/* Topic Recommendations */}
              {contact.topicRecommendations && contact.topicRecommendations.length > 0 && (
                <div>
                  <div className="flex items-center gap-2 mb-3">
                    <MessageSquare size={16} style={{ color: '#FF7F50' }} />
                    <h4 className="text-sm font-medium dark:text-white">Conversation Topics</h4>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {contact.topicRecommendations.map((topic, idx) => (
                      <button
                        key={idx}
                        onClick={() => handleTopicClick(topic)}
                        className="px-3 py-2 rounded-lg text-sm font-medium text-white hover:opacity-90 transition-all"
                        style={{
                          backgroundColor: selectedTopic === topic ? '#7C34ED' : '#FF7F50',
                          transform: selectedTopic === topic ? 'scale(1.05)' : 'scale(1)',
                          boxShadow: selectedTopic === topic ? '0 4px 6px rgba(0, 128, 128, 0.3)' : 'none'
                        }}
                      >
                        {topic}
                      </button>
                    ))}
                  </div>
                  {selectedTopic && (
                    <div className="mt-3 p-4 bg-orange-50 dark:bg-orange-900/20 border border-orange-200 dark:border-orange-800 rounded-lg">
                      <div className="flex items-start gap-2 mb-3">
                        <Lightbulb size={16} className="text-orange-600 dark:text-orange-400 flex-shrink-0 mt-0.5" />
                        <h5 className="text-sm font-semibold text-orange-900 dark:text-orange-100">{selectedTopic}</h5>
                      </div>
                      {generateTopicElaboration(selectedTopic)}
                    </div>
                  )}
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-3">
                    Click any topic to see AI suggestions
                  </p>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Communication Channels - Quick View */}
        <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm border border-gray-200 dark:border-gray-700 mb-4 transition-colors">
          <div className="flex items-center gap-2 mb-3">
            <MessageCircle size={18} style={{ color: '#7C34ED' }} />
            <h3 className="font-semibold dark:text-white">Communication Channels</h3>
          </div>
          <div className="flex flex-wrap gap-2">
            {contact.topChannels.map((channel, idx) => (
              <span key={idx} className="px-3 py-1 rounded-full text-sm text-white" style={{ backgroundColor: '#7C34ED' }}>
                {channel}
              </span>
            ))}
          </div>
        </div>

        {/* Collapsible: Interaction Details */}
        <div className="bg-white rounded-3xl shadow-lg mb-4 transition-colors overflow-hidden">
          <button
            onClick={() => setShowDetails(!showDetails)}
            className="w-full p-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
          >
            <div className="flex items-center gap-2">
              <BarChart3 size={18} style={{ color: '#7C34ED' }} />
              <h3 className="font-semibold dark:text-white">Interaction Details</h3>
            </div>
            {showDetails ? <ChevronUp size={20} className="text-gray-500" /> : <ChevronDown size={20} className="text-gray-500" />}
          </button>
          {showDetails && (
            <div className="p-4 pt-0 border-t border-gray-100 dark:border-gray-700">
              <h4 className="text-sm font-medium mb-3 text-gray-600 dark:text-gray-400">Interaction Frequency (12 months)</h4>
              <div className="grid grid-cols-12 gap-1 relative">
                {contact.interactionFrequency.map((freq, idx) => {
                  const intensity = maxActivity > 0 ? freq / maxActivity : 0;
                  const isHovered = hoveredMonth === idx;

                  return (
                    <div key={idx} className="relative">
                      <button
                        className="aspect-square w-full rounded-sm hover:ring-2 hover:ring-offset-1 transition-all cursor-pointer"
                        style={{
                          backgroundColor: intensity === 0
                            ? '#e5e7eb'
                            : `rgba(0, 128, 128, ${0.2 + intensity * 0.8})`,
                          '--tw-ring-color': '#7C34ED'
                        } as React.CSSProperties}
                        onMouseEnter={() => setHoveredMonth(idx)}
                        onMouseLeave={() => setHoveredMonth(null)}
                      />
                      {isHovered && (
                        <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 z-50 pointer-events-none">
                          <div className="bg-gray-900 dark:bg-gray-700 text-white px-3 py-2 rounded-lg shadow-lg whitespace-nowrap">
                            <div className="text-xs font-medium mb-0.5">
                              {getMonthName(idx)}
                            </div>
                            <div className="text-sm font-bold">
                              {freq} interaction{freq !== 1 ? 's' : ''}
                            </div>
                            <div className="absolute top-full left-1/2 -translate-x-1/2 -mt-1">
                              <div className="border-4 border-transparent border-t-gray-900 dark:border-t-gray-700" />
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Collapsible: Activity Log */}
        <div className="bg-white rounded-3xl shadow-lg transition-colors overflow-hidden">
          <button
            onClick={() => setShowActivityLog(!showActivityLog)}
            className="w-full p-4 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
          >
            <div className="flex items-center gap-2">
              <Mail size={18} style={{ color: '#7C34ED' }} />
              <h3 className="font-semibold dark:text-white">Activity Log</h3>
            </div>
            {showActivityLog ? <ChevronUp size={20} className="text-gray-500" /> : <ChevronDown size={20} className="text-gray-500" />}
          </button>
          {showActivityLog && (
            <div className="p-4 pt-0 border-t border-gray-100 dark:border-gray-700">
              <div className="space-y-3">
                {contact.activityLog.map((log, idx) => (
                  <div key={idx} className="flex gap-3 pb-3 border-b border-gray-100 dark:border-gray-700 last:border-0 last:pb-0">
                    <div className="text-sm text-gray-500 dark:text-gray-400 w-20 flex-shrink-0">{log.date}</div>
                    <div className="flex-1">
                      <div className="font-medium text-sm mb-1 dark:text-white">{log.type}</div>
                      <div className="text-sm text-gray-600 dark:text-gray-400">{log.notes}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Floating Update with AI Button */}
      <button
        onClick={() => onAIUpdate(contact)}
        className="fixed bottom-6 right-4 px-5 py-4 rounded-full text-white font-bold hover:scale-110 transition-all shadow-2xl flex items-center justify-center gap-2 z-50"
        style={{
          backgroundColor: '#7C34ED',
          boxShadow: '0 8px 24px rgba(124, 52, 237, 0.5)'
        }}
        title="Update with AI"
      >
        <Sparkles size={24} />
        <span className="text-sm">Update with AI</span>
      </button>
    </div>
  );
}