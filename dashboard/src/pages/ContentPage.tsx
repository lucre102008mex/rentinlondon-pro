import { useState } from "react";
import { GripVertical, ExternalLink, Image, CalendarDays, LayoutGrid } from "lucide-react";
import StatusDot from "@/components/StatusDot";

type ContentColumn = 'idea' | 'scripting' | 'recording' | 'editing' | 'scheduled' | 'published' | 'repurposed';
type Platform = 'YouTube' | 'TikTok' | 'Instagram' | 'Facebook';

interface ContentItem {
  id: string;
  title: string;
  platform: Platform;
  day: string;
  status: 'active' | 'pending' | 'idle';
}

const platformEmoji: Record<Platform, string> = {
  YouTube: '▶️',
  TikTok: '🎵',
  Instagram: '📸',
  Facebook: '📘',
};

const initialContent: Record<ContentColumn, ContentItem[]> = {
  idea: [
    { id: 'c1', title: 'Best Areas for HMOs in London 2025', platform: 'YouTube', day: 'Monday', status: 'idle' },
    { id: 'c2', title: 'How I Automate Tenant Screening', platform: 'TikTok', day: 'Wednesday', status: 'idle' },
  ],
  scripting: [
    { id: 'c3', title: 'Tenant FAQ: Deposit Protection', platform: 'YouTube', day: 'Tuesday', status: 'pending' },
  ],
  recording: [
    { id: 'c4', title: 'Property Tour: 2-Bed Stratford', platform: 'Instagram', day: 'Thursday', status: 'active' },
  ],
  editing: [
    { id: 'c5', title: 'Weekly Market Update — Zone 1-3', platform: 'YouTube', day: 'Friday', status: 'active' },
  ],
  scheduled: [
    { id: 'c6', title: 'London Property Market Tips', platform: 'YouTube', day: 'Monday', status: 'pending' },
    { id: 'c7', title: 'Behind the Scenes: AI Automation', platform: 'TikTok', day: 'Wednesday', status: 'pending' },
  ],
  published: [
    { id: 'c8', title: 'How to Find a Flat in London', platform: 'YouTube', day: 'Monday', status: 'active' },
  ],
  repurposed: [
    { id: 'c9', title: 'Top 5 Renting Mistakes (Shorts)', platform: 'TikTok', day: 'Tuesday', status: 'active' },
  ],
};

const columns: { key: ContentColumn; label: string }[] = [
  { key: 'idea', label: 'Idea' },
  { key: 'scripting', label: 'Scripting' },
  { key: 'recording', label: 'Recording' },
  { key: 'editing', label: 'Editing' },
  { key: 'scheduled', label: 'Scheduled' },
  { key: 'published', label: 'Published' },
  { key: 'repurposed', label: 'Repurposed' },
];

const weeklySchedule = [
  { day: 'Monday', theme: 'London Property Market Tips', color: 'bg-cat-leads/20 text-cat-leads' },
  { day: 'Tuesday', theme: 'Tenant FAQ / Common Questions', color: 'bg-cat-content/20 text-cat-content' },
  { day: 'Wednesday', theme: 'Behind the Scenes / Automation', color: 'bg-cat-automation/20 text-cat-automation' },
  { day: 'Thursday', theme: 'Property Tours / Listings', color: 'bg-cat-viewings/20 text-cat-viewings' },
  { day: 'Friday', theme: 'Weekly Wrap-up / Market Update', color: 'bg-priority-high/20 text-priority-high' },
];

const ContentPage = () => {
  const [content, setContent] = useState(initialContent);
  const [view, setView] = useState<'board' | 'calendar'>('board');

  const handleDragStart = (e: React.DragEvent, id: string) => {
    e.dataTransfer.setData('contentId', id);
  };

  const handleDrop = (e: React.DragEvent, target: ContentColumn) => {
    e.preventDefault();
    const id = e.dataTransfer.getData('contentId');
    const newContent = { ...content };
    let moved: ContentItem | undefined;

    for (const col of Object.keys(newContent) as ContentColumn[]) {
      const idx = newContent[col].findIndex(c => c.id === id);
      if (idx !== -1) {
        moved = newContent[col].splice(idx, 1)[0];
        break;
      }
    }
    if (moved) {
      newContent[target].push(moved);
      setContent({ ...newContent });
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Content Pipeline</h1>
          <p className="text-sm text-muted-foreground mt-1">Create and manage your content workflow</p>
        </div>
        <div className="flex items-center gap-1 bg-secondary rounded-md p-0.5">
          <button
            onClick={() => setView('board')}
            className={`px-3 py-1.5 text-xs rounded transition-colors ${view === 'board' ? 'bg-accent text-foreground' : 'text-muted-foreground'}`}
          >
            <LayoutGrid className="h-3 w-3 inline mr-1" /> Board
          </button>
          <button
            onClick={() => setView('calendar')}
            className={`px-3 py-1.5 text-xs rounded transition-colors ${view === 'calendar' ? 'bg-accent text-foreground' : 'text-muted-foreground'}`}
          >
            <CalendarDays className="h-3 w-3 inline mr-1" /> Schedule
          </button>
        </div>
      </div>

      {view === 'board' ? (
        <div className="flex gap-3 overflow-x-auto pb-4">
          {columns.map((col) => (
            <div
              key={col.key}
              onDrop={(e) => handleDrop(e, col.key)}
              onDragOver={(e) => e.preventDefault()}
              className="bg-muted/30 rounded-lg p-3 min-w-[200px] w-[200px] shrink-0 min-h-[400px]"
            >
              <div className="flex items-center gap-2 mb-4">
                <h3 className="text-[10px] font-semibold text-foreground uppercase tracking-wider">{col.label}</h3>
                <span className="text-[10px] text-muted-foreground ml-auto">{content[col.key].length}</span>
              </div>
              <div className="space-y-2">
                {content[col.key].map(item => (
                  <div
                    key={item.id}
                    draggable
                    onDragStart={(e) => handleDragStart(e, item.id)}
                    className="bg-card border border-border rounded-lg p-3 cursor-grab active:cursor-grabbing hover:border-primary/30 transition-colors group"
                  >
                    <div className="flex items-start justify-between mb-2">
                      <h4 className="text-xs font-medium text-foreground leading-tight pr-1">{item.title}</h4>
                      <GripVertical className="h-3 w-3 text-muted-foreground opacity-0 group-hover:opacity-100 shrink-0" />
                    </div>
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-[10px] text-muted-foreground">{platformEmoji[item.platform]} {item.platform}</span>
                      <StatusDot status={item.status} />
                    </div>
                    <p className="text-[10px] text-muted-foreground mt-1">{item.day}</p>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="space-y-4">
          <h2 className="text-sm font-medium text-foreground">Weekly Posting Schedule</h2>
          <div className="grid gap-3">
            {weeklySchedule.map((day) => (
              <div key={day.day} className="bg-card border border-border rounded-lg p-4 flex items-center gap-4">
                <span className="text-sm font-semibold text-foreground w-24">{day.day}</span>
                <span className={`text-xs px-2 py-1 rounded ${day.color}`}>{day.theme}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default ContentPage;
