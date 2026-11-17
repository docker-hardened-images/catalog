import {ExtensionsService} from './extensions-service';

test('resource extensions match API group and kind globs with the installed minimatch', () => {
    const component = () => null;
    const api = (window as any).extensionsAPI;
    api.registerResourceExtension(component, '*.example.io', 'Deploy*', 'Deployment details');
    api.registerResourceExtension(component, '*.example.io', 'Service', 'Service details');
    api.registerResourceExtension(component, 'other.example.com', '*', 'Other group');

    const service = new ExtensionsService();
    expect(service.getResourceTabs('apps.example.io', 'Deployment').map(tab => tab.title)).toEqual(['Deployment details']);
    expect(service.getResourceTabs('apps.example.io', 'Service').map(tab => tab.title)).toEqual(['Service details']);
    expect(service.getResourceTabs('unmatched.example.net', 'Deployment')).toEqual([]);
    expect(service.getResourceTabs('apps.example.io', 'ConfigMap')).toEqual([]);
});
