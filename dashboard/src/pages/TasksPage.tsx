import { useState } from "react";
import { Clock, User, Flag, Filter, GripVertical, Plus, Loader2, Trash2 } from "lucide-react";
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

type Priority = 'urgent' | 'high' | 'medium' | 'low';
type Column = 'todo' | 'in_progress' | 'waiting' | 'done';

interface Task {
  id: string;
  title: string;
  assignee: string;
  priority: Priority;
  due_date: string;
  project: string;
  description?: string;
  status: Column;
}

const columns: { key: Column; label: string; status: 'idle' | 'active' | 'pending' | 'success' }[] = [
  { key: 'todo', label: 'To Do', status: 'idle' },
  { key: 'in_progress', label: 'In Progress', status: 'active' },
  { key: 'waiting', label: 'Waiting / Blocked', status: 'pending' },
  { key: 'done', label: 'Done', status: 'success' },
];

const priorityColors: Record<Priority, string> = {
  urgent: 'bg-priority-urgent/20 text-priority-urgent',
  high: 'bg-priority-high/20 text-priority-high',
  medium: 'bg-priority-medium/20 text-priority-medium',
  low: 'bg-priority-low/20 text-priority-low',
};

const TaskCard = ({ task, onDragStart, onDelete }: { task: Task; onDragStart: (e: React.DragEvent, id: string) => void; onDelete: (id: string) => void }) => (
  <div
    draggable
    onDragStart={(e) => onDragStart(e, task.id)}
    className="bg-card border border-border rounded-lg p-3 cursor-grab active:cursor-grabbing hover:border-primary/30 transition-colors group shadow-sm relative"
  >
    <div className="flex items-start justify-between mb-2">
      <h4 className="text-sm font-medium text-foreground leading-tight pr-6">{task.title}</h4>
      <GripVertical className="h-3 w-3 text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity shrink-0" />
    </div>
    <p className="text-[10px] text-muted-foreground mb-3 truncate">{task.project}</p>
    <div className="flex items-center gap-2 flex-wrap">
      <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium capitalize ${priorityColors[task.priority]}`}>
        {task.priority}
      </span>
      <span className="text-[10px] text-muted-foreground flex items-center gap-1">
        <User className="h-2.5 w-2.5" />{task.assignee}
      </span>
      {task.due_date && (
        <span className="text-[10px] text-muted-foreground flex items-center gap-1">
          <Clock className="h-2.5 w-2.5" />{task.due_date}
        </span>
      )}
    </div>
    <button 
      onClick={() => onDelete(task.id)}
      className="absolute top-2 right-2 text-muted-foreground hover:text-destructive opacity-0 group-hover:opacity-100 transition-opacity p-1"
    >
      <Trash2 className="h-3 w-3" />
    </button>
  </div>
);

const TasksPage = () => {
  const queryClient = useQueryClient();
  const [filter, setFilter] = useState<string>('all');
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [newTask, setNewTask] = useState({
    title: "",
    assignee: "Me",
    priority: "medium" as Priority,
    project: "",
    description: "",
    due_date: "",
    status: "todo" as Column
  });

  const { data: tasksData = [], isLoading } = useQuery({
    queryKey: ['tasks', filter],
    queryFn: async () => {
      let query = supabase.from('dashboard_tasks').select('*');
      if (filter !== 'all') {
        query = query.ilike('project', `%${filter}%`);
      }
      const { data, error } = await query.order('created_at', { ascending: false });
      if (error) throw error;
      return data as Task[];
    }
  });

  const addTaskMutation = useMutation({
    mutationFn: async (task: Omit<Task, 'id'>) => {
      const { data, error } = await supabase.from('dashboard_tasks').insert([task]).select();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] });
      setIsAddDialogOpen(false);
      setNewTask({ title: "", assignee: "Me", priority: "medium", project: "", description: "", due_date: "", status: "todo" });
      toast.success("Task added successfully");
    },
    onError: (error) => {
      toast.error(`Error adding task: ${error.message}`);
    }
  });

  const updateTaskMutation = useMutation({
    mutationFn: async ({ id, status }: { id: string; status: Column }) => {
      const { error } = await supabase.from('dashboard_tasks').update({ status }).eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] });
    }
  });

  const deleteTaskMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('dashboard_tasks').delete().eq('id', id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] });
      toast.success("Task deleted");
    }
  });

  const handleDragStart = (e: React.DragEvent, taskId: string) => {
    e.dataTransfer.setData('taskId', taskId);
  };

  const handleDrop = (e: React.DragEvent, targetColumn: Column) => {
    e.preventDefault();
    const taskId = e.dataTransfer.getData('taskId');
    updateTaskMutation.mutate({ id: taskId, status: targetColumn });
  };

  const handleDragOver = (e: React.DragEvent) => e.preventDefault();

  const tasksByColumn: Record<Column, Task[]> = {
    todo: tasksData.filter(t => t.status === 'todo'),
    in_progress: tasksData.filter(t => t.status === 'in_progress'),
    waiting: tasksData.filter(t => t.status === 'waiting'),
    done: tasksData.filter(t => t.status === 'done'),
  };

  const handleAddTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTask.title) return;
    addTaskMutation.mutate(newTask);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground italic flex items-center gap-2">
            <Flag className="text-primary" /> Tasks Board
          </h1>
          <p className="text-sm text-muted-foreground mt-1">Manage tasks across all projects</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <Filter className="h-4 w-4 text-muted-foreground" />
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              className="bg-secondary text-secondary-foreground text-xs rounded-md px-2 py-1.5 border border-border focus:outline-none focus:ring-1 focus:ring-primary h-8"
            >
              <option value="all">All Projects</option>
              <option value="lead">Lead Management</option>
              <option value="listing">Property Listings</option>
              <option value="automation">Automation & Tech</option>
            </select>
          </div>

          <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm" className="bg-primary text-primary-foreground flex items-center gap-2 shadow-lg">
                <Plus className="h-4 w-4" /> Add Task
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-[425px]">
              <DialogHeader>
                <DialogTitle>New Task</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleAddTask} className="space-y-4 mt-4">
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Title</label>
                  <Input 
                    value={newTask.title}
                    onChange={e => setNewTask({...newTask, title: e.target.value})}
                    placeholder="Task name..."
                    required
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <label className="text-xs font-semibold">Assignee</label>
                    <Select value={newTask.assignee} onValueChange={v => setNewTask({...newTask, assignee: v})}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="Me">Me</SelectItem>
                        <SelectItem value="Jeanette">Jeanette</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-2">
                    <label className="text-xs font-semibold">Priority</label>
                    <Select value={newTask.priority} onValueChange={v => setNewTask({...newTask, priority: v as Priority})}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="low">Low</SelectItem>
                        <SelectItem value="medium">Medium</SelectItem>
                        <SelectItem value="high">High</SelectItem>
                        <SelectItem value="urgent">Urgent</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Project</label>
                  <Input 
                    value={newTask.project}
                    onChange={e => setNewTask({...newTask, project: e.target.value})}
                    placeholder="Project name..."
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Due Date</label>
                  <Input 
                    type="date"
                    value={newTask.due_date}
                    onChange={e => setNewTask({...newTask, due_date: e.target.value})}
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-xs font-semibold">Description</label>
                  <Textarea 
                    value={newTask.description}
                    onChange={e => setNewTask({...newTask, description: e.target.value})}
                    placeholder="Details..."
                  />
                </div>
                <Button type="submit" className="w-full" disabled={addTaskMutation.isPending}>
                  {addTaskMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Create Task
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
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-4 gap-4">
          {columns.map((col) => (
            <div
              key={col.key}
              onDrop={(e) => handleDrop(e, col.key)}
              onDragOver={handleDragOver}
              className="bg-muted/30 rounded-lg p-3 min-h-[400px] border border-transparent hover:border-border/50 transition-colors"
            >
              <div className="flex items-center gap-2 mb-4">
                <StatusDot status={col.status} />
                <h3 className="text-xs font-semibold text-foreground uppercase tracking-wider">{col.label}</h3>
                <span className="text-[10px] text-muted-foreground ml-auto bg-secondary px-1.5 py-0.5 rounded">{tasksByColumn[col.key].length}</span>
              </div>
              <div className="space-y-2">
                {tasksByColumn[col.key].map(task => (
                  <TaskCard key={task.id} task={task} onDragStart={handleDragStart} onDelete={(id) => {
                    if(confirm("Delete task?")) deleteTaskMutation.mutate(id);
                  }} />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default TasksPage;

