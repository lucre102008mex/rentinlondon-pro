import { useState } from "react";
import { ChevronLeft, ChevronRight, Plus, Loader2, Calendar as CalendarIcon, Trash2 } from "lucide-react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { format, startOfMonth, endOfMonth, eachDayOfInterval, getDay, isSameDay } from "date-fns";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";

interface CalEvent {
  id: string;
  title: string;
  date: string;
  time: string;
  category: 'leads' | 'content' | 'viewings' | 'automation';
  description?: string;
  reminder?: boolean;
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

const daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const CalendarPage = () => {
  const queryClient = useQueryClient();
  const [currentDate, setCurrentDate] = useState(new Date());
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [newEvent, setNewEvent] = useState({
    title: "",
    date: format(new Date(), "yyyy-MM-dd"),
    time: "10:00",
    category: "leads" as CalEvent['category'],
    description: "",
    reminder: false
  });

  const monthStart = startOfMonth(currentDate);
  const monthEnd = endOfMonth(monthStart);
  const daysInMonth = eachDayOfInterval({ start: monthStart, end: monthEnd });
  
  // Adjusted for Monday start
  const startDay = (getDay(monthStart) + 6) % 7;

  const { data: events = [], isLoading } = useQuery({
    queryKey: ['calendar-events', format(currentDate, "yyyy-MM")],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('calendar_events')
        .select('*')
        .gte('date', format(monthStart, "yyyy-MM-dd"))
        .lte('date', format(monthEnd, "yyyy-MM-dd"));
      
      if (error) throw error;
      return data as CalEvent[];
    }
  });

  const addEventMutation = useMutation({
    mutationFn: async (event: Omit<CalEvent, 'id'>) => {
      const { data, error } = await supabase.from('calendar_events').insert([event]).select();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['calendar-events'] });
      setIsAddDialogOpen(false);
      setNewEvent({ title: "", date: format(new Date(), "yyyy-MM-dd"), time: "10:00", category: "leads", description: "", reminder: false });
      toast.success("Event added successfully");
    },
    onError: (error) => {
      toast.error(`Error adding event: ${error.message}`);
    }
  });

  const deleteEventMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('calendar_events').delete().eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['calendar-events'] });
      toast.success("Event deleted");
    }
  });

  const handlePrevMonth = () => {
    setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1));
  };

  const handleNextMonth = () => {
    setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1));
  };

  const handleAddEvent = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newEvent.title || !newEvent.date) return;
    addEventMutation.mutate(newEvent);
  };

  const getDayEvents = (day: Date) => {
    return events.filter(e => isSameDay(new Date(e.date), day));
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground italic flex items-center gap-2">
            <CalendarIcon className="text-primary" /> Calendar
          </h1>
          <p className="text-sm text-muted-foreground mt-1 uppercase tracking-widest font-bold">{format(currentDate, "MMMM yyyy")}</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1">
            <button onClick={handlePrevMonth} className="p-1.5 rounded hover:bg-accent border border-border transition-colors">
              <ChevronLeft className="h-4 w-4 text-muted-foreground" />
            </button>
            <button onClick={handleNextMonth} className="p-1.5 rounded hover:bg-accent border border-border transition-colors">
              <ChevronRight className="h-4 w-4 text-muted-foreground" />
            </button>
          </div>
          
          <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm" className="bg-primary text-primary-foreground flex items-center gap-2 shadow-lg hover:scale-105 active:scale-95 transition-all">
                <Plus className="h-4 w-4" /> Add Event
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px]">
              <DialogHeader>
                <DialogTitle>Add to Calendar</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleAddEvent} className="space-y-4 mt-4">
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Title</label>
                  <Input 
                    value={newEvent.title}
                    onChange={e => setNewEvent({...newEvent, title: e.target.value})}
                    placeholder="Event title..."
                    required
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold">Date</label>
                    <Input 
                      type="date"
                      value={newEvent.date}
                      onChange={e => setNewEvent({...newEvent, date: e.target.value})}
                      required
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-semibold">Time</label>
                    <Input 
                      type="time"
                      value={newEvent.time}
                      onChange={e => setNewEvent({...newEvent, time: e.target.value})}
                    />
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Category</label>
                  <Select value={newEvent.category} onValueChange={v => setNewEvent({...newEvent, category: v as CalEvent['category']})}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="leads">Lead & Tenant</SelectItem>
                      <SelectItem value="content">Content</SelectItem>
                      <SelectItem value="viewings">Viewing / Meeting</SelectItem>
                      <SelectItem value="automation">Automation</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex items-center justify-between p-2 rounded-md bg-muted/30 border border-border">
                  <div className="space-y-0.5">
                    <label className="text-xs font-semibold">Set Reminder</label>
                    <p className="text-[10px] text-muted-foreground">Notification before event</p>
                  </div>
                  <Switch 
                    checked={newEvent.reminder}
                    onCheckedChange={v => setNewEvent({...newEvent, reminder: v})}
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Description (Optional)</label>
                  <Textarea 
                    value={newEvent.description}
                    onChange={e => setNewEvent({...newEvent, description: e.target.value})}
                    placeholder="Details..."
                  />
                </div>
                <Button type="submit" className="w-full" disabled={addEventMutation.isPending}>
                  {addEventMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Create Event
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      <div className="flex gap-4 mb-4 flex-wrap">
        {Object.entries(catLabels).map(([key, label]) => (
          <div key={key} className="flex items-center gap-1.5">
            <div className={`w-2 h-2 rounded-full`} style={{ backgroundColor: `hsl(var(--cat-${key}))` }} />
            <span className="text-[10px] text-muted-foreground font-medium uppercase tracking-tighter">{label}</span>
          </div>
        ))}
      </div>

      <div className="bg-card border border-border rounded-lg overflow-hidden shadow-xl">
        <div className="grid grid-cols-7">
          {daysOfWeek.map(d => (
            <div key={d} className="px-2 py-3 text-[10px] text-muted-foreground font-bold uppercase text-center border-b border-border bg-muted/30">
              {d}
            </div>
          ))}
        </div>
        <div className="grid grid-cols-7 relative">
          {isLoading && (
            <div className="absolute inset-0 bg-background/50 backdrop-blur-sm z-10 flex items-center justify-center">
              <Loader2 className="h-8 w-8 animate-spin text-primary" />
            </div>
          )}
          {Array.from({ length: startDay }).map((_, i) => (
            <div key={`empty-${i}`} className="min-h-[120px] border-b border-r border-border bg-muted/10 opacity-50" />
          ))}
          {daysInMonth.map(day => {
            const dayEvents = getDayEvents(day);
            const isToday = isSameDay(day, new Date());
            return (
              <div key={day.toISOString()} className={`min-h-[120px] border-b border-r border-border p-2 hover:bg-muted/5 transition-colors group ${isToday ? 'bg-primary/5' : ''}`}>
                <div className="flex justify-between items-start">
                  <span className={`text-xs font-bold leading-none ${isToday ? 'bg-primary text-primary-foreground w-5 h-5 rounded-full flex items-center justify-center shadow-md' : 'text-muted-foreground group-hover:text-foreground transition-colors'}`}>
                    {format(day, "d")}
                  </span>
                </div>
                <div className="mt-2 space-y-1">
                  {dayEvents.map(ev => (
                    <div key={ev.id} className={`text-[9px] px-1.5 py-0.5 rounded border-l-[3px] truncate font-medium shadow-sm transition-all hover:translate-x-0.5 relative group/event ${catStyles[ev.category]}`}>
                      <span className="opacity-70 mr-1">{ev.time}</span> {ev.title}
                      <button 
                        onClick={(e) => {
                          e.stopPropagation();
                          if(confirm("Delete event?")) deleteEventMutation.mutate(ev.id);
                        }}
                        className="absolute right-0 top-0 bottom-0 bg-destructive text-destructive-foreground px-1 opacity-0 group-hover/event:opacity-100 transition-opacity flex items-center"
                      >
                        <Trash2 className="h-2.5 w-2.5" />
                      </button>
                    </div>
                  ))}
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

