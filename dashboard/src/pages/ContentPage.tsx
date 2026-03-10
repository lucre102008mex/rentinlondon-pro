import { useState } from "react";
import { GripVertical, ExternalLink, Image, CalendarDays, LayoutGrid, Plus, Loader2, Trash2, Youtube, Instagram, Facebook, Music2 } from "lucide-react";
import StatusDot from "@/components/StatusDot";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
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

type ContentStage = 'idea' | 'production' | 'review' | 'scheduled' | 'published' | 'repurposed';
type Platform = 'YouTube' | 'TikTok' | 'Instagram' | 'Facebook';

interface ContentItem {
  id: string;
  title: string;
  platform: Platform;
  scheduled_day: string;
  stage: ContentStage;
  description?: string;
}

const platformIcons: Record<Platform, React.ReactNode> = {
  YouTube: <Youtube className="h-3 w-3 text-red-500" />,
  TikTok: <Music2 className="h-3 w-3 text-cyan-400" />,
  Instagram: <Instagram className="h-3 w-3 text-pink-500" />,
  Facebook: <Facebook className="h-3 w-3 text-blue-600" />,
};

const columns: { key: ContentStage; label: string }[] = [
  { key: 'idea', label: 'Idea 💡' },
  { key: 'production', label: 'Production 🎬' },
  { key: 'review', label: 'Review 📝' },
  { key: 'scheduled', label: 'Scheduled 🗓️' },
  { key: 'published', label: 'Published ✅' },
  { key: 'repurposed', label: 'Repurposed ♻️' },
];

const weeklySchedule = [
  { day: 'Monday', theme: 'London Property Market Tips', color: 'bg-cat-leads/20 text-cat-leads' },
  { day: 'Tuesday', theme: 'Tenant FAQ / Common Questions', color: 'bg-cat-content/20 text-cat-content' },
  { day: 'Wednesday', theme: 'Behind the Scenes / Automation', color: 'bg-cat-automation/20 text-cat-automation' },
  { day: 'Thursday', theme: 'Property Tours / Listings', color: 'bg-cat-viewings/20 text-cat-viewings' },
  { day: 'Friday', theme: 'Weekly Wrap-up / Market Update', color: 'bg-priority-high/20 text-priority-high' },
];

const ContentPage = () => {
  const queryClient = useQueryClient();
  const [view, setView] = useState<'board' | 'calendar'>('board');
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [newItem, setNewItem] = useState({
    title: "",
    platform: "YouTube" as Platform,
    scheduled_day: "Monday",
    stage: "idea" as ContentStage,
    description: ""
  });

  const { data: contentData = [], isLoading } = useQuery({
    queryKey: ['content-items'],
    queryFn: async () => {
      const { data, error } = await supabase.from('content_items').select('*').order('created_at', { ascending: false });
      if (error) throw error;
      return data as ContentItem[];
    }
  });

  const addItemMutation = useMutation({
    mutationFn: async (item: Omit<ContentItem, 'id'>) => {
      const { data, error } = await supabase.from('content_items').insert([item]).select();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['content-items'] });
      setIsAddDialogOpen(false);
      setNewItem({ title: "", platform: "YouTube", scheduled_day: "Monday", stage: "idea", description: "" });
      toast.success("Content item added");
    },
    onError: (error) => {
      toast.error(`Error: ${error.message}`);
    }
  });

  const updateStageMutation = useMutation({
    mutationFn: async ({ id, stage }: { id: string; stage: ContentStage }) => {
      const { error } = await supabase.from('content_items').update({ stage }).eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['content-items'] });
    }
  });

  const deleteItemMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('content_items').delete().eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['content-items'] });
      toast.success("Content deleted");
    }
  });

  const handleDragStart = (e: React.DragEvent, id: string) => {
    e.dataTransfer.setData('contentId', id);
  };

  const handleDrop = (e: React.DragEvent, target: ContentStage) => {
    e.preventDefault();
    const id = e.dataTransfer.getData('contentId');
    updateStageMutation.mutate({ id, stage: target });
  };

  const handleAddContent = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newItem.title) return;
    addItemMutation.mutate(newItem);
  };

  const itemsByStage: Record<ContentStage, ContentItem[]> = {
    idea: contentData.filter(i => i.stage === 'idea'),
    production: contentData.filter(i => i.stage === 'production'),
    review: contentData.filter(i => i.stage === 'review'),
    scheduled: contentData.filter(i => i.stage === 'scheduled'),
    published: contentData.filter(i => i.stage === 'published'),
    repurposed: contentData.filter(i => i.stage === 'repurposed'),
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground italic flex items-center gap-2">
            <LayoutGrid className="text-primary" /> Content Pipeline
          </h1>
          <p className="text-sm text-muted-foreground mt-1 uppercase tracking-widest font-bold">Manage your social media strategy</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1 bg-secondary rounded-lg p-1 border border-border shadow-inner">
            <button
              onClick={() => setView('board')}
              className={`px-4 py-1.5 text-xs font-bold rounded-md transition-all ${view === 'board' ? 'bg-background text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground'}`}
            >
              <LayoutGrid className="h-3.5 w-3.5 inline mr-1.5" /> Board
            </button>
            <button
              onClick={() => setView('calendar')}
              className={`px-4 py-1.5 text-xs font-bold rounded-md transition-all ${view === 'calendar' ? 'bg-background text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground'}`}
            >
              <CalendarDays className="h-3.5 w-3.5 inline mr-1.5" /> Schedule
            </button>
          </div>

          <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm" className="bg-primary hover:bg-primary/90 text-primary-foreground flex items-center gap-2 shadow-lg hover:scale-105 active:scale-95 transition-all">
                <Plus className="h-4 w-4" /> New Content
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px]">
              <DialogHeader>
                <DialogTitle>Add New Content</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleAddContent} className="space-y-4 mt-4">
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Title</label>
                  <Input 
                    value={newItem.title}
                    onChange={e => setNewItem({...newItem, title: e.target.value})}
                    placeholder="E.g., 5 Tips for Renting in London..."
                    required
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold">Platform</label>
                    <Select value={newItem.platform} onValueChange={v => setNewItem({...newItem, platform: v as Platform})}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="YouTube">YouTube</SelectItem>
                        <SelectItem value="TikTok">TikTok</SelectItem>
                        <SelectItem value="Instagram">Instagram</SelectItem>
                        <SelectItem value="Facebook">Facebook</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-semibold">Scheduled Day</label>
                    <Select value={newItem.scheduled_day} onValueChange={v => setNewItem({...newItem, scheduled_day: v})}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {weeklySchedule.map(s => (
                          <SelectItem key={s.day} value={s.day}>{s.day}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Description (Optional)</label>
                  <Textarea 
                    value={newItem.description}
                    onChange={e => setNewItem({...newItem, description: e.target.value})}
                    placeholder="Technical details, hooks or captions..."
                  />
                </div>
                <Button type="submit" className="w-full" disabled={addItemMutation.isPending}>
                  {addItemMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Save Content Idea
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center min-h-[400px]">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      ) : view === 'board' ? (
        <div className="flex gap-4 overflow-x-auto pb-4 scrollbar-thin scrollbar-thumb-border">
          {columns.map((col) => (
            <div
              key={col.key}
              onDrop={(e) => handleDrop(e, col.key)}
              onDragOver={(e) => e.preventDefault()}
              className="bg-muted/20 rounded-xl p-4 min-w-[260px] w-[260px] shrink-0 min-h-[500px] border border-border/50 hover:bg-muted/30 transition-all shadow-inner"
            >
              <div className="flex items-center gap-2 mb-4 border-b border-border/50 pb-2">
                <h3 className="text-[11px] font-black text-foreground/80 uppercase tracking-tighter">{col.label}</h3>
                <span className="text-[10px] font-bold bg-primary/10 text-primary px-2 py-0.5 rounded-full ml-auto border border-primary/20">{itemsByStage[col.key].length}</span>
              </div>
              <div className="space-y-3">
                {itemsByStage[col.key].map(item => (
                  <div
                    key={item.id}
                    draggable
                    onDragStart={(e) => handleDragStart(e, item.id)}
                    className="bg-card border border-border rounded-xl p-4 cursor-grab active:cursor-grabbing hover:border-primary/40 transition-all group shadow-sm hover:shadow-lg relative overflow-hidden"
                  >
                    <div className="absolute top-0 left-0 w-1 h-full bg-primary opacity-20" />
                    <div className="flex items-start justify-between mb-3">
                      <h4 className="text-xs font-bold text-foreground leading-tight line-clamp-2 pr-4">{item.title}</h4>
                      <GripVertical className="h-3 w-3 text-muted-foreground opacity-20 group-hover:opacity-100 shrink-0 transition-opacity" />
                    </div>
                    <div className="flex items-center gap-3 mt-4 pt-3 border-t border-border/40">
                      <div className="flex items-center gap-1.5 shrink-0">
                        {platformIcons[item.platform]}
                        <span className="text-[10px] text-muted-foreground font-bold uppercase tracking-tight">{item.platform}</span>
                      </div>
                      <span className="text-[10px] text-muted-foreground/60 font-medium ml-auto">{item.scheduled_day}</span>
                    </div>
                    <button 
                      onClick={() => {
                        if(confirm("Delete content item?")) deleteItemMutation.mutate(item.id);
                      }}
                      className="absolute top-2 right-2 p-1.5 text-muted-foreground/30 hover:text-destructive hover:bg-destructive/10 rounded-md transition-all opacity-0 group-hover:opacity-100"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="space-y-6 max-w-5xl">
          <div className="grid gap-4">
            {weeklySchedule.map((day) => {
              const dayItems = contentData.filter(i => i.scheduled_day === day.day);
              return (
                <div key={day.day} className="bg-card border border-border rounded-xl p-5 flex flex-col gap-4 shadow-sm hover:shadow-md transition-all relative overflow-hidden group">
                  <div className="flex items-center justify-between border-b border-border pb-3">
                    <div className="flex items-center gap-3">
                      <div className={`w-2.5 h-2.5 rounded-full ${day.color.split(' ')[0]}`} />
                      <span className="text-sm font-black text-foreground uppercase tracking-tight">{day.day}</span>
                    </div>
                    <span className={`text-[10px] font-black px-3 py-1 rounded-full border border-current/20 uppercase tracking-tighter list-none flex items-center gap-2 ${day.color}`}>
                      <CalendarDays className="h-3 w-3" /> {day.theme}
                    </span>
                  </div>
                  <div className="flex flex-wrap gap-3">
                    {dayItems.length > 0 ? dayItems.map(item => (
                      <div key={item.id} className="bg-secondary/40 px-3 py-2 rounded-lg text-[10px] flex items-center gap-2.5 border border-border/50 hover:bg-secondary/60 transition-colors group/item relative">
                        <span className="flex items-center justify-center p-1 bg-background rounded border border-border/50">{platformIcons[item.platform]}</span>
                        <div>
                          <p className="font-bold text-foreground leading-none">{item.title}</p>
                          <p className="text-[9px] text-muted-foreground mt-1 font-medium capitalize italic">{item.stage}</p>
                        </div>
                        <button 
                          onClick={() => {
                            if(confirm("Delete content item?")) deleteItemMutation.mutate(item.id);
                          }}
                          className="ml-2 text-muted-foreground/20 hover:text-destructive transition-colors opacity-0 group-hover/item:opacity-100"
                        >
                          <Trash2 className="h-3 w-3" />
                        </button>
                      </div>
                    )) : (
                      <div className="flex items-center gap-2 text-[10px] text-muted-foreground/50 italic py-2">
                        <span>No content planned for this day yet. Click "New Content" to start.</span>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};

export default ContentPage;

