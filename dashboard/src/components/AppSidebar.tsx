import {
  LayoutDashboard, KanbanSquare, Newspaper, Calendar, Brain,
  Bot, Users, Settings, Shield, Activity, Building2, RefreshCw, Key
} from "lucide-react";
import { NavLink } from "@/components/NavLink";
import { useLocation } from "react-router-dom";
import {
  Sidebar, SidebarContent, SidebarGroup, SidebarGroupContent,
  SidebarMenu, SidebarMenuButton, SidebarMenuItem, useSidebar,
} from "@/components/ui/sidebar";
import StatusDot from "./StatusDot";

const navItems = [
  { title: "Dashboard", url: "/", icon: LayoutDashboard },
  { title: "Void Properties", url: "/void-properties", icon: Building2 },
  { title: "Reactivations", url: "/reactivations", icon: RefreshCw },
  { title: "Tasks", url: "/tasks", icon: KanbanSquare },
  { title: "Content", url: "/content", icon: Newspaper },
  { title: "Calendar", url: "/calendar", icon: Calendar },
  { title: "Memory", url: "/memory", icon: Brain },
  { title: "AI Team", url: "/ai-team", icon: Bot },
  { title: "Agent Control", url: "/agent-control", icon: Shield },
  { title: "Telemetry", url: "/telemetry", icon: Activity },
  { title: "Token Control", url: "/tokens", icon: Key },
  { title: "Contacts", url: "/contacts", icon: Users },
  { title: "Settings", url: "/settings", icon: Settings },
];

export function AppSidebar() {
  const { state } = useSidebar();
  const collapsed = state === "collapsed";
  const location = useLocation();

  return (
    <Sidebar collapsible="icon">
      <SidebarContent>
        <div className={`p-4 ${collapsed ? 'px-2' : ''}`}>
          {!collapsed ? (
            <div className="flex items-center gap-3 mb-1">
              <div className="w-8 h-8 rounded-lg bg-primary/20 flex items-center justify-center">
                <span className="text-primary font-bold text-sm">MC</span>
              </div>
              <div>
                <h2 className="text-sm font-semibold text-foreground">Mission Control</h2>
                <p className="text-[10px] text-muted-foreground">RentInLondon</p>
              </div>
            </div>
          ) : (
            <div className="w-8 h-8 rounded-lg bg-primary/20 flex items-center justify-center mx-auto">
              <span className="text-primary font-bold text-xs">MC</span>
            </div>
          )}
        </div>

        {!collapsed && (
          <div className="mx-4 mb-4 p-3 rounded-lg bg-secondary/50 border border-border">
            <div className="flex items-center gap-2 mb-1">
              <StatusDot status="active" />
              <span className="text-xs font-medium text-foreground">Jeanette</span>
            </div>
            <p className="text-[10px] text-muted-foreground">Lead AI Agent — Online</p>
          </div>
        )}

        <SidebarGroup>
          <SidebarGroupContent>
            <SidebarMenu>
              {navItems.map((item) => (
                <SidebarMenuItem key={item.title}>
                  <SidebarMenuButton asChild>
                    <NavLink
                      to={item.url}
                      end={item.url === '/'}
                      className="hover:bg-accent"
                      activeClassName="bg-accent text-primary font-medium"
                    >
                      <item.icon className="h-4 w-4 mr-2 shrink-0" />
                      {!collapsed && <span>{item.title}</span>}
                    </NavLink>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>
    </Sidebar>
  );
}
