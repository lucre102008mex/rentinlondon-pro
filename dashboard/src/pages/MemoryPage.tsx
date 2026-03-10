import { useState } from "react";
import { Search, Filter, FileText, Calendar, Tag, X, Plus, Loader2, Upload, Trash2, ImageIcon } from "lucide-react";
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

interface MemoryDoc {
  id: string;
  title: string;
  category: string;
  content: string;
  image_url?: string;
  created_at: string;
}

const categories = [
  'All',
  'Tenant Scripts & AI Prompts',
  'Property Listings & Descriptions',
  'Automation SOPs & Workflows',
  'Landlord & Supplier Notes',
  'Archive',
];

const MemoryPage = () => {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [catFilter, setCatFilter] = useState('All');
  const [selected, setSelected] = useState<MemoryDoc | null>(null);
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  
  const [newItem, setNewItem] = useState({
    title: "",
    category: "Tenant Scripts & AI Prompts",
    content: "",
    image_url: ""
  });

  const { data: docs = [], isLoading } = useQuery({
    queryKey: ['memory-docs'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('memory_docs')
        .select('*')
        .order('created_at', { ascending: false });
      if (error) throw error;
      return data as MemoryDoc[];
    }
  });

  const addDocMutation = useMutation({
    mutationFn: async (doc: Omit<MemoryDoc, 'id' | 'created_at'>) => {
      const { data, error } = await supabase.from('memory_docs').insert([doc]).select();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['memory-docs'] });
      setIsAddDialogOpen(false);
      setNewItem({ title: "", category: "Tenant Scripts & AI Prompts", content: "", image_url: "" });
      toast.success("Memory document added");
    },
    onError: (error) => {
      toast.error(`Error: ${error.message}`);
    }
  });

  const deleteDocMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('memory_docs').delete().eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['memory-docs'] });
      setSelected(null);
      toast.success("Document deleted");
    }
  });

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      setIsUploading(true);
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;
      const filePath = `${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('memory-images')
        .upload(filePath, file);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('memory-images')
        .getPublicUrl(filePath);

      setNewItem({ ...newItem, image_url: publicUrl });
      toast.success("Image uploaded successfully");
    } catch (error: any) {
      toast.error("Error uploading image: " + error.message);
    } finally {
      setIsUploading(false);
    }
  };

  const handleAddSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newItem.title || !newItem.content) return;
    addDocMutation.mutate(newItem);
  };

  const filtered = docs.filter(d => {
    const matchesSearch = d.title.toLowerCase().includes(search.toLowerCase()) || d.content.toLowerCase().includes(search.toLowerCase());
    const matchesCat = catFilter === 'All' || d.category === catFilter;
    return matchesSearch && matchesCat;
  });

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Memory</h1>
          <p className="text-sm text-muted-foreground mt-1">Searchable knowledge base and document library</p>
        </div>
        
        <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
          <DialogTrigger asChild>
            <Button size="sm" className="bg-primary text-primary-foreground flex items-center gap-2 shadow-lg">
              <Plus className="h-4 w-4" /> New Memo
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[500px]">
            <DialogHeader>
              <DialogTitle>Add to System Memory</DialogTitle>
            </DialogHeader>
            <form onSubmit={handleAddSubmit} className="space-y-4 mt-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Title</label>
                  <Input 
                    value={newItem.title}
                    onChange={e => setNewItem({...newItem, title: e.target.value})}
                    placeholder="Doc title..."
                    required
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Category</label>
                  <Select value={newItem.category} onValueChange={v => setNewItem({...newItem, category: v})}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {categories.filter(c => c !== 'All').map(c => (
                        <SelectItem key={c} value={c}>{c}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              
              <div className="space-y-2">
                <label className="text-xs font-semibold">Content / Body</label>
                <Textarea 
                  value={newItem.content}
                  onChange={e => setNewItem({...newItem, content: e.target.value})}
                  placeholder="Paste instructions, scripts or notes here..."
                  className="min-h-[150px]"
                  required
                />
              </div>

              <div className="space-y-2">
                <label className="text-xs font-semibold">Attachment (Image)</label>
                <div className="flex items-center gap-4">
                  <div className="relative flex-1">
                    <Input 
                      type="file" 
                      accept="image/*" 
                      onChange={handleFileUpload}
                      className="cursor-pointer"
                      disabled={isUploading}
                    />
                    {isUploading && (
                      <div className="absolute inset-0 bg-background/50 flex items-center justify-center rounded-md">
                        <Loader2 className="h-4 w-4 animate-spin" />
                      </div>
                    )}
                  </div>
                  {newItem.image_url && (
                    <div className="h-10 w-10 rounded border border-border overflow-hidden shrink-0">
                      <img src={newItem.image_url} alt="Preview" className="h-full w-full object-cover" />
                    </div>
                  )}
                </div>
              </div>

              <Button type="submit" className="w-full" disabled={addDocMutation.isPending || isUploading}>
                {addDocMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                Save to Memory
              </Button>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <div className="flex gap-3">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search documents..."
            className="w-full bg-secondary border border-border rounded-lg pl-9 pr-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-primary"
          />
        </div>
        <select
          value={catFilter}
          onChange={(e) => setCatFilter(e.target.value)}
          className="bg-secondary text-secondary-foreground text-xs rounded-lg px-3 py-2 border border-border"
        >
          {categories.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center min-h-[400px]">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      ) : selected ? (
        <div className="bg-card border border-border rounded-lg p-6 shadow-sm">
          <div className="flex items-start justify-between mb-4 pb-4 border-b border-border">
            <div className="flex gap-4">
              {selected.image_url && (
                <div className="w-24 h-24 rounded-lg overflow-hidden border border-border shrink-0">
                  <img src={selected.image_url} alt={selected.title} className="w-full h-full object-cover" />
                </div>
              )}
              <div>
                <h2 className="text-xl font-bold text-foreground">{selected.title}</h2>
                <div className="flex items-center gap-3 mt-2">
                  <span className="text-[10px] text-muted-foreground flex items-center gap-1">
                    <Calendar className="h-3 w-3" /> {new Date(selected.created_at).toLocaleDateString()}
                  </span>
                  <span className="text-[10px] bg-primary/10 text-primary px-2 py-0.5 rounded font-medium border border-primary/20">
                    {selected.category}
                  </span>
                </div>
              </div>
            </div>
            <div className="flex gap-2">
              <button 
                onClick={() => {
                  if (confirm("Are you sure you want to delete this memo?")) {
                    deleteDocMutation.mutate(selected.id);
                  }
                }}
                className="p-1.5 hover:bg-destructive/10 text-destructive rounded-lg transition-colors"
                title="Delete"
              >
                <Trash2 className="h-4 w-4" />
              </button>
              <button onClick={() => setSelected(null)} className="p-1.5 hover:bg-accent rounded-lg transition-colors">
                <X className="h-4 w-4 text-muted-foreground" />
              </button>
            </div>
          </div>
          <div className="prose prose-sm max-w-none dark:prose-invert">
            <p className="text-sm text-foreground/90 leading-relaxed whitespace-pre-wrap">{selected.content}</p>
          </div>
        </div>
      ) : filtered.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(doc => (
            <div
              key={doc.id}
              onClick={() => setSelected(doc)}
              className="bg-card border border-border rounded-lg p-4 cursor-pointer hover:border-primary/40 transition-all hover:shadow-md flex flex-col group"
            >
              <div className="flex gap-3 mb-3">
                {doc.image_url ? (
                  <div className="w-12 h-12 rounded border border-border overflow-hidden shrink-0">
                    <img src={doc.image_url} alt={doc.title} className="w-full h-full object-cover" />
                  </div>
                ) : (
                  <div className="w-12 h-12 rounded bg-secondary flex items-center justify-center shrink-0 text-muted-foreground">
                    <FileText className="h-5 w-5" />
                  </div>
                )}
                <div>
                  <h3 className="text-sm font-bold text-foreground leading-tight line-clamp-2 group-hover:text-primary transition-colors">{doc.title}</h3>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="text-[10px] bg-secondary text-secondary-foreground px-1.5 py-0.5 rounded font-medium">{doc.category}</span>
                  </div>
                </div>
              </div>
              <p className="text-[11px] text-muted-foreground mb-4 line-clamp-3 leading-relaxed flex-grow">
                {doc.content}
              </p>
              <div className="flex items-center justify-between pt-3 border-t border-border/50">
                <span className="text-[10px] text-muted-foreground flex items-center gap-1">
                  <Calendar className="h-2.5 w-2.5" />{new Date(doc.created_at).toLocaleDateString()}
                </span>
                <span className="text-[10px] font-bold text-primary opacity-0 group-hover:opacity-100 transition-opacity">Read more →</span>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center min-h-[300px] border-2 border-dashed border-border rounded-xl">
          <FileText className="h-12 w-12 text-muted-foreground/30 mb-4" />
          <p className="text-muted-foreground text-sm italic">No documents found matching your search.</p>
        </div>
      )}
    </div>
  );
};

export default MemoryPage;

