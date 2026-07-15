import '../main.dart';

class ProjectService {
  Future<void> addTestProject() async {
    await supabase.from('projects').insert({
      'project_name': 'Project A',
    });
  }
}