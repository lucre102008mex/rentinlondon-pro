import { useState } from "react";
import { Clock, User, Flag, Filter, GripVertical } from "lucide-react";
import StatusDot from "@/components/StatusDot";

type Priority = 'urgent' | 'high' | 'medium' | 'low';
type Assignee = 'Me' | 'Jeanette';
type Column = 'todo' | 'in_progress' | 'waiting' | 'done';

interface Task {
  id: string;
  title: string;
  assignee: Assignee;
  priority: Priority;
  dueDate: string;
  project: string;
  description?: string;
}

const initialTasks: Record<Column, Task[]> = {
  todo: [
    { id: '1', title: 'Set up Facebook Marketplace auto-responder', assignee: 'Jeanette', priority: 'high', dueDate: 'Mar 10', project: 'Automation & Tech Infrastructure' },
    { id: '2', title: 'Draft tenant qualification questionnaire v2', assignee: 'Me', priority: 'medium', dueDate: 'Mar 11', project: 'Lead Management & Tenant Qualification' },
    { id: '3', title: 'Research competitor pricing in Zone 2', assignee: 'Jeanette', priority: 'low', dueDate: 'Mar 12', project: 'Property Listings & Marketing' },
  ],
  in_progress: [
    { id: '4', title: 'WhatsApp lead response automation', assignee: 'Jeanette', priority: 'urgent', dueDate: 'Mar 9', project: 'Automation & Tech Infrastructure' },
    { id: '5', title: 'Update Gumtree listings with new photos', assignee: 'Me', priority: 'high', dueDate: 'Mar 9', project: 'Property Listings & Marketing' },
  ],
  waiting: [
    { id: '6', title: 'Landlord approval for Shoreditch flat pricing', assignee: 'Me', priority: 'medium', dueDate: 'Mar 10', project: 'Property Listings & Marketing' },
    { id: '7', title: 'AWS EC2 instance upgrade pending', assignee: 'Jeanette', priority: 'high', dueDate: 'Mar 8', project: 'Automation & Tech Infrastructure' },
  ],
  done: [
    { id: '8', title: 'Set up BeehIiv newsletter template', assignee: 'Me', priority: 'medium', dueDate: 'Mar 7', project: 'Property Listings & Marketing' },
    { id: '9', title: 'Qualify 15 Gumtree leads', assignee: 'Jeanette', priority: 'high', dueDate: 'Mar 7', project: 'Lead Management & Tenant Qualification' },
  ],
};

const columns: { key: Column; label: string; status: 'idle' | 'active' | 'pending' | 'active' }[] = [
  { key: 'todo', label: 'To Do', status: 'idle' },
  { key: 'in_progress', label: 'In Progress', status: 'active' },
  { key: 'waiting', label: 'Waiting / Blocked', status: 'pending' },
  { key: 'done', label: 'Done', status: 'active' },
];

const priorityColors: Record<Priority, string> = {
  urgent: 'bg-priority-urgent/20 text-priority-urgent',
  high: 'bg-priority-high/20 text-priority-high',
  medium: 'bg-priority-medium/20 text-priority-medium',
  low: 'bg-priority-low/20 text-priority-low',
};

const TaskCard = ({ task, onDragStart }: { task: Task; onDragStart: (e: React.DragEvent, id: string) => void }) => (
  <div
    draggable
    onDragStart={(e) => onDragStart(e, task.id)}
    className="bg-card border border-border rounded-lg p-3 cursor-grab active:cursor-grabbing hover:border-primary/30 transition-colors group"
  >
    <div className="flex items-start justify-between mb-2">
      <h4 className="text-sm font-medium text-foreground leading-tight pr-2">{task.title}</h4>
      <GripVertical className="h-3 w-3 text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity shrink-0" />
    </div>
    <p className="text-[10px] text-muted-foreground mb-3">{task.project}</p>
    <div className="flex items-center gap-2 flex-wrap">
      <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${priorityColors[task.priority]}`}>
        {task.priority}
      </span>
      <span className="text-[10px] text-muted-foreground flex items-center gap-1">
        <User className="h-2.5 w-2.5" />{task.assignee}
      </span>
      <span className="text-[10px] text-muted-foreground flex items-center gap-1">
        <Clock className="h-2.5 w-2.5" />{task.dueDate}
      </span>
    </div>
  </div>
);

const TasksPage = () => {
  const [tasks, setTasks] = useState(initialTasks);
  const [filter, setFilter] = useState<string>('all');

  const handleDragStart = (e: React.DragEvent, taskId: string) => {
    e.dataTransfer.setData('taskId', taskId);
  };

  const handleDrop = (e: React.DragEvent, targetColumn: Column) => {
    e.preventDefault();
    const taskId = e.dataTransfer.getData('taskId');
    const newTasks = { ...tasks };
    let movedTask: Task | undefined;

    for (const col of Object.keys(newTasks) as Column[]) {
      const idx = newTasks[col].findIndex(t => t.id === taskId);
      if (idx !== -1) {
        movedTask = newTasks[col].splice(idx, 1)[0];
        break;
      }
    }

    if (movedTask) {
      newTasks[targetColumn].push(movedTask);
      setTasks({ ...newTasks });
    }
  };

  const handleDragOver = (e: React.DragEvent) => e.preventDefault();

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Tasks Board</h1>
          <p className="text-sm text-muted-foreground mt-1">Manage tasks across all projects</p>
        </div>
        <div className="flex items-center gap-2">
          <Filter className="h-4 w-4 text-muted-foreground" />
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="bg-secondary text-secondary-foreground text-xs rounded-md px-2 py-1.5 border border-border"
          >
            <option value="all">All Projects</option>
            <option value="leads">Lead Management</option>
            <option value="listings">Property Listings</option>
            <option value="automation">Automation & Tech</option>
          </select>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-4">
        {columns.map((col) => (
          <div
            key={col.key}
            onDrop={(e) => handleDrop(e, col.key)}
            onDragOver={handleDragOver}
            className="bg-muted/30 rounded-lg p-3 min-h-[400px]"
          >
            <div className="flex items-center gap-2 mb-4">
              <StatusDot status={col.status} />
              <h3 className="text-xs font-semibold text-foreground uppercase tracking-wider">{col.label}</h3>
              <span className="text-[10px] text-muted-foreground ml-auto">{tasks[col.key].length}</span>
            </div>
            <div className="space-y-2">
              {tasks[col.key].map(task => (
                <TaskCard key={task.id} task={task} onDragStart={handleDragStart} />
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default TasksPage;
