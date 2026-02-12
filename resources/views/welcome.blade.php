<!DOCTYPE html>
<html>
<head>
    <title>Laravel CRUD Testing</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 flex items-center justify-center h-screen">
    <div class="bg-white p-8 rounded shadow-md w-96">
        
        <div class="text-center mb-6">
            <h2 class="text-2xl font-bold text-gray-800">Task List - Development</h2>
            
            <p class="text-sm text-blue-500 mt-1">
                {{ env('APP_URL') }}
            </p>

            <span class="inline-block bg-gray-200 rounded-full px-3 py-1 text-xs font-semibold text-gray-700 mt-2">
                Laravel v{{ app()->version() }}
            </span>
        </div>

        <form action="{{ route('todo.store') }}" method="POST" class="mb-4 flex gap-2">
            @csrf
            <input type="text" name="task" class="border p-2 w-full rounded focus:outline-none focus:ring-2 focus:ring-blue-400" placeholder="New Task..." required>
            <button type="submit" class="bg-blue-500 hover:bg-blue-600 text-white px-4 rounded transition">Add</button>
        </form>

        <ul class="space-y-2">
            @foreach($todos as $todo)
                <li class="flex justify-between items-center bg-gray-50 p-2 rounded border hover:bg-gray-100 transition">
                    <span class="text-gray-700">{{ $todo->task }}</span>
                    <form action="{{ route('todo.destroy', $todo->id) }}" method="POST">
                        @csrf @method('DELETE')
                        <button class="text-red-500 hover:text-red-700 font-bold px-2">✕</button>
                    </form>
                </li>
            @endforeach
        </ul>
        
    </div>
</body>
</html>
