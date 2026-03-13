import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import Layout from "./components/Layout";
import DashboardPage from "./pages/DashboardPage";
import TasksPage from "./pages/TasksPage";
import ContentPage from "./pages/ContentPage";
import CalendarPage from "./pages/CalendarPage";
import MemoryPage from "./pages/MemoryPage";
import AITeamPage from "./pages/AITeamPage";
import AgentControlPage from "./pages/AgentControlPage";
import TelemetryPage from "./pages/TelemetryPage";
import ContactsPage from "./pages/ContactsPage";
import SettingsPage from "./pages/SettingsPage";
import NotFound from "./pages/NotFound";

import VoidPropertiesPage from "./pages/VoidPropertiesPage";
import ReactivationsPage from "./pages/ReactivationsPage";
import TokenManagementPage from "./pages/TokenManagementPage";
import AgentOperationsPage from "./pages/AgentOperationsPage";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <Layout>
          <Routes>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/tasks" element={<TasksPage />} />
            <Route path="/content" element={<ContentPage />} />
            <Route path="/calendar" element={<CalendarPage />} />
            <Route path="/memory" element={<MemoryPage />} />
            <Route path="/ai-team" element={<AITeamPage />} />
            <Route path="/agent-control" element={<AgentControlPage />} />
            <Route path="/telemetry" element={<TelemetryPage />} />
            <Route path="/contacts" element={<ContactsPage />} />
            <Route path="/void-properties" element={<VoidPropertiesPage />} />
            <Route path="/reactivations" element={<ReactivationsPage />} />
<Route path="/tokens" element={<TokenManagementPage />} />
        <Route path="/agent-operations" element={<AgentOperationsPage />} />
        <Route path="/settings" element={<SettingsPage />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </Layout>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
