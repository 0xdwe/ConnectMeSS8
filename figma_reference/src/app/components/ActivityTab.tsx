import { Trophy, Star, CheckCircle2, Circle } from 'lucide-react';
import { Task } from './mock-data';

interface ActivityTabProps {
  tasks: Task[];
  currentPoints: number;
  currentLevel: number;
  nextLevelPoints: number;
  onTaskComplete: (taskId: string) => void;
}

export function ActivityTab({
  tasks,
  currentPoints,
  currentLevel,
  nextLevelPoints,
  onTaskComplete
}: ActivityTabProps) {
  const progressPercentage = (currentPoints / nextLevelPoints) * 100;
  const completedTasks = tasks.filter(t => t.completed).length;
  const totalTasks = tasks.length;

  return (
    <div className="p-4 min-h-screen">
      <div className="rounded-2xl p-6 text-white shadow-lg mb-6" style={{ background: 'linear-gradient(135deg, #FF7F50 0%, #A96039 100%)' }}>
        <div className="flex items-center gap-2 mb-3">
          <Trophy size={24} />
          <span className="font-semibold">Level {currentLevel}</span>
        </div>
        <div className="mb-2">
          <div className="flex justify-between text-sm mb-1">
            <span>{currentPoints} XP</span>
            <span>{nextLevelPoints} XP</span>
          </div>
          <div className="w-full bg-white/30 rounded-full h-3 overflow-hidden">
            <div
              className="bg-white h-full rounded-full transition-all duration-500"
              style={{ width: `${progressPercentage}%` }}
            />
          </div>
        </div>
        <div className="text-sm opacity-90">
          {nextLevelPoints - currentPoints} XP to next level
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm border border-gray-200 dark:border-gray-700 mb-6 transition-colors">
        <div className="flex justify-between items-center">
          <div>
            <div className="text-2xl font-bold" style={{ color: '#C5A8E8' }}>{completedTasks}/{totalTasks}</div>
            <div className="text-sm" style={{ color: '#737877' }}>Tasks Completed</div>
          </div>
          <div>
            <div className="text-2xl font-bold" style={{ color: '#FF7F50' }}>{currentPoints}</div>
            <div className="text-sm" style={{ color: '#737877' }}>Total Points</div>
          </div>
        </div>
      </div>

      <div>
        <h3 className="font-semibold mb-3 flex items-center gap-2 dark:text-white">
          <Star size={18} style={{ color: '#FF7F50' }} />
          Social Challenges
        </h3>
        <div className="space-y-3">
          {tasks.map(task => (
            <div
              key={task.id}
              className={`bg-white dark:bg-gray-800 rounded-lg p-4 shadow-sm border transition-all ${
                task.completed
                  ? 'border-green-300 dark:border-green-700 bg-green-50 dark:bg-green-900/20'
                  : 'border-gray-200 dark:border-gray-700 hover:border-purple-400'
              }`}
            >
              <div className="flex items-start gap-3">
                <button
                  onClick={() => onTaskComplete(task.id)}
                  className="mt-0.5 flex-shrink-0"
                  style={{ color: task.completed ? '#C5A8E8' : '#737877' }}
                  onMouseEnter={(e) => !task.completed && (e.currentTarget.style.color = '#C5A8E8')}
                  onMouseLeave={(e) => !task.completed && (e.currentTarget.style.color = '#737877')}
                >
                  {task.completed ? (
                    <CheckCircle2 size={24} />
                  ) : (
                    <Circle size={24} />
                  )}
                </button>
                <div className="flex-1">
                  <h4 className={`font-medium mb-1 ${task.completed ? 'line-through text-gray-500 dark:text-gray-400' : 'dark:text-white'}`}>
                    {task.title}
                  </h4>
                  <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">{task.description}</p>
                  <div className="flex items-center gap-2">
                    <span className="text-xs px-2 py-1 rounded-full text-white" style={{ backgroundColor: '#A96039' }}>
                      {task.category}
                    </span>
                    <span className="text-xs px-2 py-1 rounded-full font-medium text-white" style={{ backgroundColor: '#FF7F50' }}>
                      +{task.points} XP
                    </span>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
