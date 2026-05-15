export interface Contact {
  id: string;
  name: string;
  email: string;
  category: 'Family' | 'Friends' | 'High School' | 'College' | 'Work' | 'Other';
  knownSince: string;
  bondScore: number;
  lastContact: string;
  avatar: string;
  topChannels: string[];
  interactionFrequency: number[];
  aiTip: string;
  activityLog: {
    date: string;
    type: string;
    notes: string;
  }[];
  aiSummary?: string;
  topicRecommendations?: string[];
}

export interface Event {
  id: string;
  date: string;
  title: string;
  contactId?: string;
  type: 'plan' | 'reminder' | 'birthday';
  isAllDay?: boolean;
  startTime?: string;
  endTime?: string;
  isRecurring?: boolean;
  recurrencePattern?: 'daily' | 'weekly' | 'monthly' | 'yearly';
}

export interface Task {
  id: string;
  title: string;
  description: string;
  points: number;
  completed: boolean;
  category: string;
}

export const mockContacts: Contact[] = [
  {
    id: '1',
    name: 'Sarah Johnson',
    email: 'sarah.j@email.com',
    category: 'Friends',
    knownSince: '2015-08-20',
    bondScore: 92,
    lastContact: '2026-04-25',
    avatar: '👩',
    topChannels: ['Phone', 'WhatsApp', 'In-Person'],
    interactionFrequency: [3, 5, 2, 4, 6, 3, 5, 4, 3, 2, 4, 5],
    aiTip: "It's been 2 days since your last interaction. Consider sending a quick message to catch up!",
    activityLog: [
      { date: '2026-04-25', type: 'Call', notes: 'Caught up about weekend plans' },
      { date: '2026-04-18', type: 'Coffee', notes: 'Met at downtown cafe, tried their new cold brew' },
      { date: '2026-04-10', type: 'Message', notes: 'Shared funny meme about coffee addicts' },
      { date: '2026-03-28', type: 'In-Person', notes: 'Discussed weekend hiking trip ideas' },
      { date: '2026-03-15', type: 'Message', notes: 'Recommended new brunch spot on Main St' }
    ],
    aiSummary: "Sarah is an active and engaged friend who you've known for 11 years. Your relationship shows strong consistency with regular coffee meetups and phone calls. Recent interactions suggest you both enjoy spontaneous catch-ups and share humor through memes. Sarah seems to value face-to-face time, with downtown cafe being a favorite spot.",
    topicRecommendations: ['Weekend plans', 'Coffee shop recommendations', 'Funny stories', 'Local events']
  },
  {
    id: '2',
    name: 'Mike Chen',
    email: 'mike.chen@email.com',
    category: 'High School',
    knownSince: '2010-09-01',
    bondScore: 68,
    lastContact: '2026-03-15',
    avatar: '👨',
    topChannels: ['Email', 'LinkedIn', 'Text'],
    interactionFrequency: [1, 2, 1, 0, 1, 2, 1, 1, 0, 1, 1, 2],
    aiTip: "You haven't connected in over a month. A quick 'thinking of you' message could brighten their day!",
    activityLog: [
      { date: '2026-03-15', type: 'Email', notes: 'Shared career update about new job offer in tech' },
      { date: '2026-02-01', type: 'LinkedIn', notes: 'Commented on his post about AI trends in industry' },
      { date: '2026-01-10', type: 'Call', notes: 'New Year catch up, discussed career goals for 2026' },
      { date: '2025-12-20', type: 'Message', notes: 'Reminisced about high school basketball team' },
      { date: '2025-11-15', type: 'Email', notes: 'Asked about job application at Google' }
    ],
    aiSummary: "Mike is a high school friend you've maintained contact with for 16 years, primarily through professional channels. Recent interactions show he's career-focused and active on LinkedIn. The relationship would benefit from more personal touchpoints to strengthen the bond beyond professional updates.",
    topicRecommendations: ['Career goals', 'High school memories', 'Industry trends', 'Personal hobbies']
  },
  {
    id: '3',
    name: 'Emily Rodriguez',
    email: 'emily.r@email.com',
    category: 'Work',
    knownSince: '2022-01-15',
    bondScore: 85,
    lastContact: '2026-04-26',
    avatar: '👩‍💼',
    topChannels: ['Slack', 'Email', 'Zoom'],
    interactionFrequency: [4, 5, 5, 4, 5, 4, 5, 5, 4, 4, 5, 4],
    aiTip: 'Great momentum! Consider scheduling a coffee chat to deepen the relationship.',
    activityLog: [
      { date: '2026-04-26', type: 'Slack', notes: 'Discussed project timeline for Q2 deliverables' },
      { date: '2026-04-24', type: 'Meeting', notes: 'Weekly sync - reviewed sprint progress' },
      { date: '2026-04-20', type: 'Email', notes: 'Shared resources for new API implementation' },
      { date: '2026-04-15', type: 'Coffee', notes: 'Casual coffee chat about work-life balance' },
      { date: '2026-04-08', type: 'Slack', notes: 'Talked about career development opportunities' }
    ],
    aiSummary: "Emily is a work colleague you've known for 4 years with excellent communication frequency. Your interactions are primarily project-focused through Slack and meetings, showing strong professional rapport. The relationship has potential to deepen beyond work topics with more informal conversations.",
    topicRecommendations: ['Project updates', 'Career development', 'Work-life balance', 'Coffee chat']
  },
  {
    id: '4',
    name: 'David Kim',
    email: 'david.k@email.com',
    category: 'Family',
    knownSince: '1995-06-12',
    bondScore: 95,
    lastContact: '2026-04-27',
    avatar: '👨‍👦',
    topChannels: ['Phone', 'In-Person', 'WhatsApp'],
    interactionFrequency: [5, 6, 5, 5, 6, 5, 6, 5, 5, 6, 5, 6],
    aiTip: 'Strong bond! Keep up the regular communication.',
    activityLog: [
      { date: '2026-04-27', type: 'Phone', notes: 'Morning check-in about family gathering plans' },
      { date: '2026-04-26', type: 'Dinner', notes: 'Family dinner at home with the kids' },
      { date: '2026-04-23', type: 'Message', notes: 'Shared photos from family beach day' },
      { date: '2026-04-20', type: 'Call', notes: 'Discussed upcoming family reunion in June' },
      { date: '2026-04-15', type: 'In-Person', notes: 'Helped with kids soccer practice' }
    ],
    aiSummary: "David is a close family member you've known for 31 years with an exceptional bond. Your relationship is characterized by daily check-ins, regular family dinners, and photo sharing. The communication is consistent and multi-channel, showing a deeply rooted and well-maintained family connection.",
    topicRecommendations: ['Family updates', 'Shared memories', 'Daily life', 'Future plans']
  },
  {
    id: '5',
    name: 'Jessica Taylor',
    email: 'jess.t@email.com',
    category: 'College',
    knownSince: '2012-09-01',
    bondScore: 73,
    lastContact: '2026-04-01',
    avatar: '👩‍🎓',
    topChannels: ['Instagram', 'Text', 'FaceTime'],
    interactionFrequency: [2, 3, 2, 1, 2, 3, 2, 1, 2, 2, 1, 2],
    aiTip: "It's been almost a month. A video call could be a nice way to reconnect!",
    activityLog: [
      { date: '2026-04-01', type: 'Instagram', notes: 'Liked vacation photos from her trip to Bali' },
      { date: '2026-03-10', type: 'Text', notes: 'Birthday wishes and asked about Europe trip plans' },
      { date: '2026-02-14', type: 'FaceTime', notes: 'Caught up about life and travel bucket list' },
      { date: '2026-01-20', type: 'Message', notes: 'She shared photos from Thailand vacation' },
      { date: '2025-12-05', type: 'Text', notes: 'Discussed college reunion memories' }
    ],
    aiSummary: "Jessica is a college friend from 14 years ago who stays connected through social media and video calls. Recent interactions show she enjoys traveling and values meaningful catch-up conversations. The relationship follows a pattern of special occasion check-ins and social media engagement.",
    topicRecommendations: ['Travel stories', 'College memories', 'Life updates', 'Video call plans']
  }
];

export const mockEvents: Event[] = [
  { id: 'e1', date: '2026-04-28', title: 'Coffee with Sarah', contactId: '1', type: 'plan', isAllDay: false, startTime: '10:00', endTime: '11:30' },
  { id: 'e2', date: '2026-04-30', title: 'Team Meeting', type: 'plan', isAllDay: false, startTime: '14:00', endTime: '15:30' },
  { id: 'e3', date: '2026-05-05', title: 'Call Mike (Reminder)', contactId: '2', type: 'reminder', isAllDay: true },
  { id: 'e4', date: '2026-05-12', title: "Emily's Birthday", contactId: '3', type: 'birthday', isAllDay: true },
  { id: 'e5', date: '2026-05-15', title: 'Family Dinner', contactId: '4', type: 'plan', isAllDay: false, startTime: '18:30', endTime: '21:00' }
];

export const mockTasks: Task[] = [
  {
    id: 't1',
    title: 'Call your High School Friend',
    description: 'Reach out to Mike Chen - over 1 month since last contact',
    points: 50,
    completed: false,
    category: 'High School'
  },
  {
    id: 't2',
    title: 'Send a Thank You Message',
    description: 'Thank Emily for help on the recent project',
    points: 30,
    completed: false,
    category: 'Work'
  },
  {
    id: 't3',
    title: 'Schedule Monthly Family Call',
    description: 'Set up a video call with extended family',
    points: 40,
    completed: true,
    category: 'Family'
  },
  {
    id: 't4',
    title: 'Comment on a Friend\'s Post',
    description: 'Engage with Jessica\'s recent updates',
    points: 20,
    completed: false,
    category: 'College'
  },
  {
    id: 't5',
    title: 'Plan a Weekend Hangout',
    description: 'Organize an activity with your close friends',
    points: 60,
    completed: false,
    category: 'Friends'
  }
];

export const mockUser = {
  name: 'Alex Martinez',
  email: 'alex.martinez@email.com',
  avatar: '👤',
  connectionScore: 82,
  totalConnections: 5,
  totalPoints: 240,
  currentLevel: 7,
  nextLevelPoints: 300,
  heatmapData: [4, 3, 5, 2, 4, 3, 5, 4, 3, 2, 4, 5]
};

export const mockRecommendations = [
  {
    contactId: '2',
    contactName: 'Mike Chen',
    reason: 'Over 1 month since last contact',
    priority: 'high',
    topic: 'You talked about his job application last time',
    bondScore: 68,
    scoreGain: 10
  },
  {
    contactId: '5',
    contactName: 'Jessica Taylor',
    reason: '3 weeks without interaction',
    priority: 'medium',
    topic: 'She mentioned planning a trip to Europe',
    bondScore: 73,
    scoreGain: 8
  },
  {
    contactId: '3',
    contactName: 'Emily Rodriguez',
    reason: 'Great momentum - keep it going!',
    priority: 'low',
    topic: 'This is her first week at the new role',
    bondScore: 85,
    scoreGain: 5
  }
];