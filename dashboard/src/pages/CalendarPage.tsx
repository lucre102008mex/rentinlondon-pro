import { useState } from "react";
import { ChevronLeft, ChevronRight, Plus } from "lucide-react";

interface CalEvent {
  id: string;
  title: string;
  date: number;
  time: string;
  category: 'leads' | 'content' | 'viewings' | 'automation';
}

const catStyles: Record<string, string> = {
  leads: 'border-l-cat-leads bg-cat-leads/10 text-cat-leads',
  content: 'border-l-cat-content bg-cat-content/10 text-cat-content',
  viewings: 'border-l-cat-viewings bg-cat-viewings/10 text-cat-viewings',
  automation: 'border-l-cat-automation bg-cat-automation/10 text-cat-automation',
};

const catLabels: Record<string, string> = {
  leads: 'Lead & Tenant',
  content: 'Content',
  viewings: 'Viewing / Meeting',
  automation: 'Automation',
};

const sampleEvents: CalEvent[] = [
  { id: '1', title: 'Post: Market Tips Video', date: 10, time: '9:00', category: 'content' },
  { id: '2', title: 'Viewing: 2-Bed Stratford', date: 10, time: '14:00', category: 'viewings' },
  { id: '3', title: 'Lead qualification batch', date: 11, time: '10:00', category: 'leads' },
  { id: '4', title: 'Post: Tenant FAQ', date: 11, time: '12:00', category: 'content' },
  { id: '5', title: 'Cron: Price update', date: 12, time: '06:00', category: 'automation' },
  { id: '6', title: 'Landlord call — Shoreditch', date: 12, time: '15:00', category: 'viewings' },
  { id: '7', title: 'Post: Behind the Scenes', date: 12, time: '11:00', category: 'content' },
  { id: '8', title: 'Viewing: Studio Brixton', date: 13, time: '10:00', category: 'viewings' },
  { id: '9', title: 'Post: Property Tour', date: 13, time: '14:00', category: 'content' },
  { id: '10', title: 'WhatsApp bot health check', date: 14, time: '08:00', category: 'automation' },
  { id: '11', title: 'Post: Weekly Wrap-up', date: 14, time: '16:00', category: 'content' },
  { id: '12', title: 'New lead follow-up batch', date: 15, time: '09:00', category: 'leads' },
  { id: '13', title: 'Cron: Competitor scan', date: 16, time: '06:00', category: 'automation' },
];

const daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const CalendarPage = () => {
  const [view, setView] = useState<'month' | 'week' | 'day'>('month');
  const month = 'March 2026';
  const daysInMonth = 31;
  const startDay = 6; // March 2026 starts on Sunday, offset for Mon-start = 6

  const getDayEvents = (day: number) => sampleEvents.filter(e => e.date === day);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Calendar</h1>
          <p className="text-sm text-muted-foreground mt-1">{month}</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1 bg-secondary rounded-md p-0.5">
            {(['month', 'week', 'day'] as const).map(v => (
              <button
                key={v}
                onClick={() => setView(v)}
                className={`px-3 py-1.5 text-xs rounded capitalize transition-colors ${view === v ? 'bg-accent text-foreground' : 'text-muted-foreground'}`}
              >
                {v}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-1">
            <button className="p-1.5 rounded hover:bg-accent"><ChevronLeft className="h-4 w-4 text-muted-foreground" /></button>
            <button className="p-1.5 rounded hover:bg-accent"><ChevronRight className="h-4 w-4 text-muted-foreground" /></button>
          </div>
        </div>
      </div>

      {/* Legend */}
      <div className="flex gap-4">
        {Object.entries(catLabels).map(([key, label]) => (
          <div key={key} className="flex items-center gap-1.5">
            <div className={`w-2.5 h-2.5 rounded-sm bg-cat-${key}`} style={{ backgroundColor: `hsl(var(--cat-${key}))` }} />
            <span className="text-[10px] text-muted-foreground">{label}</span>
          </div>
        ))}
      </div>

      {/* Month grid */}
      <div className="bg-card border border-border rounded-lg overflow-hidden">
        <div className="grid grid-cols-7">
          {daysOfWeek.map(d => (
            <div key={d} className="px-2 py-2 text-[10px] text-muted-foreground font-semibold uppercase text-center border-b border-border">
              {d}
            </div>
          ))}
        </div>
        <div className="grid grid-cols-7">
          {Array.from({ length: startDay }).map((_, i) => (
            <div key={`empty-${i}`} className="min-h-[100px] border-b border-r border-border bg-muted/20" />
          ))}
          {Array.from({ length: daysInMonth }, (_, i) => i + 1).map(day => {
            const events = getDayEvents(day);
            const isToday = day === 8;
            return (
              <div key={day} className={`min-h-[100px] border-b border-r border-border p-1.5 ${isToday ? 'bg-primary/5' : ''}`}>
                <span className={`text-xs font-medium ${isToday ? 'bg-primary text-primary-foreground w-5 h-5 rounded-full flex items-center justify-center' : 'text-muted-foreground'}`}>
                  {day}
                </span>
                <div className="mt-1 space-y-0.5">
                  {events.slice(0, 3).map(ev => (
                    <div key={ev.id} className={`text-[9px] px-1 py-0.5 rounded border-l-2 truncate ${catStyles[ev.category]}`}>
                      {ev.title}
                    </div>
                  ))}
                  {events.length > 3 && (
                    <span className="text-[9px] text-muted-foreground">+{events.length - 3} more</span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default CalendarPage;
